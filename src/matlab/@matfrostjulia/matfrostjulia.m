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

            if numel(indexOp) == 2 && string(indexOp(1).Name) == "kwargs"
                varargout{1} = MATFrost.Kwargs(indexOp(end).Indices{:});
                return;
            end

            fully_qualified_name_arr = arrayfun(@(in) string(in.Name), indexOp(1:end-1));
            % Parse positional arguments, signature metadata and explicit Julia kwargs.
            [arguments, signature, kwargs] = parseArguments( indexOp(end).Indices{:} );
            % This is the object being sent to MATLAB 
            callstruct.id = obj.id;
            callstruct.action = "CALL";
            callmeta.fully_qualified_name = join(fully_qualified_name_arr, ".");
            callmeta.signature = signature;
            callstruct.callstruct = {callmeta; arguments(:); kwargs};

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

            function [args, signature, kwargs] = parseArguments(varargin)
                signature = [];
                kwargs = struct();
                args = varargin;

                if numel(args) >= 2 && isTextScalar(args{end-1}) && normalizeKey(args{end-1}) == "signature"
                    validateSignature(args{end}, numel(args)-2);
                    signature = args{end};
                    args = args(1:end-2);
                end

                if ~isempty(args) && isa(args{end}, 'MATFrost.Kwargs')
                    kwargs = args{end}.Data;
                    args = args(1:end-1);
                end

                if any(cellfun(@(x) isa(x, 'MATFrost.Kwargs'), args))
                    throw(MException("matfrostjulia:invalidKwargsPosition", ...
                        "MATFrost.Kwargs must be the final argument."));
                end

                function ok = validateSignature(x, nArgs)
                    if nargin>1 && numel(x) ~= nArgs
                        throw(MException("matfrostjulia:invalidSignatureSize", ...
                            "Cannot parse 'signature': number of signature entries (%d) does not equal number of arguments (%d).", ...
                            numel(x), nArgs))
                    elseif ~isstring(x)
                        throw(MException("matfrostjulia:invalidSignature", ...
                        "Cannot parse 'signature': all signature entries must be strings. Got: %s", ...
                        evalc('disp(x)')))
                    end
                    ok = true;
                end

                function key = normalizeKey(x)
                    if isstring(x) && isscalar(x)
                        key = lower(strtrim(x));
                    elseif ischar(x)
                        key = lower(strtrim(string(x)));
                    else
                        throw(MException("matfrostjulia:invalidKeyword", ...
                            "Keyword argument names must be string scalars or char vectors. Got: %s", ...
                            class(x)));
                    end
                end

                function ok = isTextScalar(x)
                    ok = (isstring(x) && isscalar(x)) || ischar(x);
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
