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
        sysimage          (1,1) string = ""
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
                argstruct.sysimage    (1,1) string {mustBeFile}
                    % Custom system image, passed as --sysimage.

                argstruct.timeout     (1,1) uint64 = 24*60*60*1000 % 1day
            end
            
            obj.id = uint64(randi(1e9, 'int32'));

            obj.host = "127.0.0.1";
            obj.port = int64(0);

            obj.timeout = argstruct.timeout;
            obj.project = argstruct.project;

            if isfield(argstruct, 'sysimage')
                [~, sysimage_info] = fileattrib(argstruct.sysimage);
                obj.sysimage = string(sysimage_info.Name);
            end

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

    methods (Static)
        function message = enhanceMultipleMethodDefinitionsMessage(message)
            message = localEnhanceMultipleMethodDefinitionsMessage(message);
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

            if strlength(obj.sysimage) > 0
                sysimage_cmdline = sprintf("--sysimage=""%s""", obj.sysimage);
            else
                sysimage_cmdline = "";
            end

            bootstrap = fullfile(fileparts(mfilename("fullpath")), "bootstrap.jl");

            createstruct = struct;
            createstruct.id = obj.id;
            createstruct.action = "START";
            createstruct.host = obj.host;
            createstruct.port = obj.port;
            createstruct.timeout = obj.timeout;
            createstruct.cmdline = sprintf("%s %s %s ""%s""", obj.julia, sysimage_cmdline, project_cmdline, bootstrap);
            
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

            % Remove any name-value pair for 'signature' from the call-site indices so
            % that parseArguments only sees the real positional arguments.
            [positional_args, signature, kwsignature, kwargs_struct] = parseArguments( indexOp(end).Indices{:} );

            % This is the object being sent to MATLAB 
            callstruct.id = obj.id;
            callstruct.action = "CALL";
            callmeta.fully_qualified_name = join(fully_qualified_name_arr, ".");
            callmeta.signature = signature;
            callmeta.kwsignature = kwsignature;
            callstruct.callstruct = {callmeta; positional_args(:); kwargs_struct};

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
                    v = enhanceErrorMessage(v);
                    throw(MException(v.id, "%s", v.message));
                else
                    throw(MException( "matfrostjulia:error", "%s", string(v)));
                end
            end

            function [positional, signature, kwsignature, kwargs_struct] = parseArguments(varargin)
                % Hard boundary: only known params (e.g. 'signature') trigger inputParser.
                % Inline Julia kwargs are discovered by scanning the positional portion
                % from the right for trailing (string_key, value) pairs, but only when
                % a non-string element provides an unambiguous break — preventing
                % positional string arguments from being misread as kwarg keys.
                %
                % When keyword arguments are present, 'signature' must be supplied and
                % must cover both positional and keyword argument types, in that order:
                % signature = [Tpos1, ..., TposN, Tkw1, ..., TkwM], where Tkw1..TkwM
                % correspond, in order, to the keyword arguments as they were parsed.

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

                % Extract trailing inline kwargs from the positional portion.
                [positional, inline_kw] = trailingKwargs(pre_args);

                % Merge inline kwargs with any unmatched name-value params after 'signature'.
                kwargs_struct = inline_kw;
                fn_kw = fieldnames(post_kw);
                for fni = 1:numel(fn_kw)
                    kwargs_struct.(fn_kw{fni}) = post_kw.(fn_kw{fni});
                end

                nPositionalArgs = numel(positional);
                nKwargs = numel(fieldnames(kwargs_struct));

                validateSignature(sig_result, nPositionalArgs + nKwargs);

                if nKwargs > 0 && isempty(sig_result)
                    throw(MException("matfrostjulia:missingKwargsSignature", ...
                        "Calls with keyword arguments require an explicit 'signature' covering " + ...
                        "both positional and keyword argument types, e.g. signature=[Tpos1,...,TposN,Tkw1,...,TkwM]."));
                end

                if isempty(sig_result)
                    signature   = sig_result;
                    kwsignature = sig_result;
                else
                    signature   = sig_result(1:nPositionalArgs);
                    kwsignature = sig_result(nPositionalArgs+1:end);
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
function v = enhanceErrorMessage(v)

    switch string(v.id)
        case "matfrostjulia:call:multipleMethodDefinitions"
            v.message = localEnhanceMultipleMethodDefinitionsMessage( ...
                v.message);
    end

end


function message = localEnhanceMultipleMethodDefinitionsMessage(message)

    lines = splitlines(string(message));

    availableIdx = find( ...
        startsWith(strtrim(lines), "Available methods:"), ...
        1);

    if isempty(availableIdx)
        return
    end

    methodLines = strings(0, 1);
    firstMethodTypes = strings(0, 1);

    for k = availableIdx + 1:numel(lines)
        line = strtrim(lines(k));

        if startsWith(line, "[")
            methodLines(end + 1, 1) = lines(k);

            if isempty(firstMethodTypes)
                tokens = regexp( ...
                    line, ...
                    '::([^,\)\s]+(?:\{[^}]*\})?)', ...
                    'tokens');

                if ~isempty(tokens)
                    firstMethodTypes = strings(numel(tokens), 1);

                    for tokenIdx = 1:numel(tokens)
                        firstMethodTypes(tokenIdx) = ...
                            string(tokens{tokenIdx}{1});
                    end
                end
            end

        elseif ~isempty(methodLines)
            break
        end
    end

    if isempty(methodLines) || isempty(firstMethodTypes)
        return
    end

    if isscalar(firstMethodTypes)
        signatureHint = sprintf( ...
            'signature="%s"', ...
            firstMethodTypes(1));
    else
        quotedTypes = """" + firstMethodTypes + """";

        signatureHint = sprintf( ...
            'signature=[%s]', ...
            strjoin(quotedTypes, ", "));
    end

    message = join( ...
        [ ...
            lines(1:availableIdx); ...
            methodLines; ...
            ""; ...
            "Hint:"; ...
            "  " + signatureHint ...
        ], ...
        newline);

end