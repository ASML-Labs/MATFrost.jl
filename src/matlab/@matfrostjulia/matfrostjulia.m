classdef matfrostjulia < handle & matlab.mixin.indexing.RedefinesDot
% matfrostjulia - Embedding Julia in MATLAB
%
% MATFrost enables quick and easy embedding of Julia functions from MATLAB side.
%
% Characteristics:
% - Converts MATLAB values into objects of any nested Julia datatype (concrete entirely).
% - Interface is defined on Julia side.
% - A single redistributable MEX file.
% - Leveraging Julia environments for reproducible builds.
% - Julia runs in its own mexhost process.



    properties (SetAccess=immutable)
        julia             (1,1) string
    end

    properties (Access=private)
        id                (1,1) uint64
        mh                     matlab.mex.MexHost
        project           (1,1) string
        host              (1,1) string
        port              (1,1) int64
        timeout           (1,1) uint64
    end

    properties (Constant, Access=private)
        USE_MEXHOST (1,1) logical = false
    end

    methods
        function obj = matfrostjulia(argstruct)
            arguments                
                argstruct.version     (1,1) string
                    % The version of Julia to use. i.e. 1.12 (Juliaup channel)
                argstruct.bindir      (1,1) string {mustBeFolder}
                    % The directory where the Julia binary is located.
                    % This will overrule the version specification.
                    % NOTE: Only needed if version is not specified.
                argstruct.project     (1,1) string = ""

                argstruct.timeout     (1,1) uint64 = 24*60*60*1000 % 1day
            end
            
            obj.id = uint64(randi(1e9, 'int32'));

            obj.host = "127.0.0.1";
            obj.port = int64(0);

            obj.timeout = argstruct.timeout;
            obj.project = argstruct.project;

            if isfield(argstruct, 'bindir')
                if ispc()
                    obj.julia = """" + fullfile(argstruct.bindir, "julia.exe") + """";
                elseif isunix()
                    obj.julia = """" + fullfile(argstruct.bindir, "julia") + """";
                end
            elseif isfield(argstruct, 'version')
                obj.julia = "julia +" + argstruct.version;
            else
                obj.julia = "julia";
            end
            
            obj.start_server();

        end


    end

    methods (Access=private)

        function obj = start_server(obj)

            obj.mh = mexhost();

            if ~isempty(obj.project)
                project_cmdline = sprintf("--project=""%s""", obj.project);
            else
                project_cmdline = "";
            end

            bootstrap = fullfile(fileparts(mfilename("fullpath")), "bootstrap.jl");

            createstruct = struct;
            createstruct.id = obj.id;
            createstruct.action = "START";
            createstruct.host = obj.host;
            createstruct.port = obj.port;
            createstruct.timeout = obj.timeout;
            createstruct.cmdline = sprintf("%s %s ""%s""", obj.julia, project_cmdline, bootstrap);
            
            if obj.USE_MEXHOST
                obj.mh.feval("matfrostjuliacall", createstruct);
            else
                matfrostjuliacall(createstruct);
            end
        end



        function delete(obj)

            destroystruct = struct;
            destroystruct.id = obj.id;
            destroystruct.action = "STOP";

            if obj.USE_MEXHOST
                obj.mh.feval("matfrostjuliacall", destroystruct);
            else
                matfrostjuliacall(destroystruct);
            end
        end
    end
   
    methods (Access=protected)
        function varargout = dotReference(obj,indexOp)
            % Calls into the loaded julia package.
            if indexOp(end).Type ~= matlab.indexing.IndexingOperationType.Paren
                throw(MException("matfrostjulia:invalidCallSignature", "Call signature is missing parentheses."));
            end
            fully_qualified_name_arr = arrayfun(@(in) string(in.Name), indexOp(1:end-1));

            % Intercept mjl.kwargs(...) and construct a kwargs object locally
            % so users never need the bare kwargs class on their MATLAB path.
            if isequal(fully_qualified_name_arr, "kwargs")
                varargout{1} = kwargs(indexOp(end).Indices{:});
                return;
            end

            % Remove any name-value pair for 'signature' from the call-site indices so
            % that parseArguments only sees the real positional arguments.
            [arguments, signature, kwargs_inline] = parseArguments( indexOp(end).Indices{:} );

            % Separate explicit kwargs objects from positional arguments (backward compat).
            kwidx = cellfun(@(a) isa(a, 'kwargs'), arguments);
            merged_kwargs = kwargs_inline;          % start from inline name=value kwargs
            for kwobj_i = find(kwidx)
                kwobj_fn = fieldnames(arguments{kwobj_i}.Data);
                for kwobj_fi = 1:numel(kwobj_fn)
                    merged_kwargs.(kwobj_fn{kwobj_fi}) = arguments{kwobj_i}.Data.(kwobj_fn{kwobj_fi});
                end
            end
            positional_args = arguments(~kwidx);

            % This is the object being sent to MATLAB 
            callstruct.id = obj.id;
            callstruct.action = "CALL";
            callmeta.fully_qualified_name = join(fully_qualified_name_arr, ".");
            callmeta.signature = signature;
            callstruct.callstruct = {callmeta; positional_args(:); merged_kwargs};

            if obj.USE_MEXHOST
                jlo = obj.mh.feval("matfrostjuliacall", callstruct);
            else
                jlo = matfrostjuliacall(callstruct);
            end
            
            if jlo.status == "SUCCESFUL"
                varargout{1} = jlo.value;
            elseif jlo.status =="ERROR"
                v = jlo.value;

                if isfield(v, "id") && isfield(v,"message")
                    switch v.id
                        case "matfrostjulia:call:multipleMethodDefinitions"
                            lines = splitlines(string(v.message));
                            idx = find(startsWith(lines, ["Example usage:","Available methods:"]));
                            if ~isempty(idx)
                                pattern = '::(\w+(?:\{[^}]*\})?)';
                                tokens = regexp(lines(idx(1)+1), pattern, 'tokens');
                                % Format for the new error message
                                lines(idx(2)+1) = sprintf("%s( ..., signature=[%s]) \n \t to uniquely identify [1] as the targeted method", callmeta.fully_qualified_name, strjoin("""" + tokens + """", ", "));
                                v.message = join(lines(1:idx(2)+2),newline);
                            end
                    end
                    throw(MException(v.id, "%s", v.message));
                else
                    throw(MException("matfrostjulia:error", v))
                end
            end

            function [args, signature, kwargs_struct] = parseArguments(varargin)
                % Hard boundary: only known params (e.g. 'signature') trigger inputParser.
                % Inline Julia kwargs are discovered by scanning the positional portion
                % from the right for trailing (string_key, value) pairs, but only when
                % a non-string element provides an unambiguous break — preventing
                % positional string arguments from being misread as kwarg keys.

                p = inputParser; p.KeepUnmatched = true;
                addParameter(p, 'signature', [], @(x) validateSignature(x));

                firstKnownParam = find(cellfun(@(x) isstring(x) && isscalar(x) && ...
                    any(ismember(x, string(p.Parameters))), varargin), 1);

                if isempty(firstKnownParam)
                    pre_args   = varargin;
                    sig_result = [];
                    post_kw    = struct();
                else
                    parse(p, varargin{firstKnownParam:end});
                    pre_args   = varargin(1:firstKnownParam-1);
                    sig_result = p.Results.signature;
                    post_kw    = p.Unmatched;
                end

                % Position check for explicit kwargs objects.
                kwmask = cellfun(@(a) isa(a, 'kwargs'), pre_args);
                if any(kwmask)
                    first_kw = find(kwmask, 1, 'first');
                    last_pos = find(~kwmask, 1, 'last');
                    if ~isempty(last_pos) && last_pos > first_kw
                        throw(MException("matfrostjulia:invalidKwargsPosition", ...
                            "Positional arguments must come before keyword arguments (kwargs)."));
                    end
                end

                % Extract trailing inline kwargs from the non-object portion.
                pure_args = pre_args(~kwmask);
                [positional, inline_kw] = trailingKwargs(pure_args);

                % Return positionals + explicit kwargs objects (dotReference extracts them).
                args = [positional, pre_args(kwmask)];

                % Validate signature against true positional count.
                nPositionalArgs = numel(positional);
                if validateSignature(sig_result, nPositionalArgs)
                    signature = sig_result;
                end

                % Merge inline kwargs with any unmatched params after 'signature'.
                kwargs_struct = inline_kw;
                fn_kw = fieldnames(post_kw);
                for fni = 1:numel(fn_kw)
                    kwargs_struct.(fn_kw{fni}) = post_kw.(fn_kw{fni});
                end

                function [pos, kw] = trailingKwargs(cell_args)
                    % Scan from the right for trailing (string_key, value) pairs.
                    % Only extracts when a non-string element causes a clear break;
                    % falls back to treating everything as positional otherwise.
                    n_args   = numel(cell_args);
                    boundary = n_args + 1;
                    i        = n_args;
                    found_break = false;
                    while i >= 2
                        ckey = cell_args{i-1};
                        if isstring(ckey) && isscalar(ckey) && isvarname(char(ckey))
                            boundary = i - 1;
                            i = i - 2;
                        else
                            found_break = true;
                            boundary = i + 1;
                            break;
                        end
                    end
                    if ~found_break && i == 1
                        ckey = cell_args{1};
                        if ~(isstring(ckey) && isscalar(ckey) && isvarname(char(ckey)))
                            found_break = true;
                        end
                    end
                    if ~found_break
                        pos = cell_args; kw = struct(); return;
                    end

                    % Conservative rule: without explicit signature, only interpret
                    % trailing inline kwargs when there are at least 2 key/value pairs.
                    npairs = (n_args - boundary + 1) / 2;
                    if isempty(sig_result) && npairs < 2
                        pos = cell_args; kw = struct(); return;
                    end

                    pos = cell_args(1:boundary-1);
                    kw  = struct();
                    for kwpair_i = boundary:2:n_args
                        kw.(char(cell_args{kwpair_i})) = cell_args{kwpair_i+1};
                    end
                end

                function ok = validateSignature(x, nArgs)
                    if nargin > 1 && ~isempty(x) && numel(x) ~= nArgs
                        throw(MException("matfrostjulia:invalidSignatureSize", ...
                            "Cannot parse 'signature': number of signature entries (%d) does not equal number of arguments (%d).", ...
                            numel(x), nArgs))
                    elseif ~isempty(x) && ~isstring(x)
                        throw(MException("matfrostjulia:invalidSignature", ...
                        "Cannot parse 'signature': all signature entries must be strings. Got: %s", ...
                        evalc('disp(x)')))
                    end
                    ok = true;
                end
            end
                
        end

        function obj = dotAssign(obj,indexOp,varargin)
            % required for matlab.mixin.indexing.RedefinesDot
        end
        
        function n = dotListLength(obj,indexOp,indexContext)
            % required for matlab.mixin.indexing.RedefinesDot
            n=1;
        end
    end
end
