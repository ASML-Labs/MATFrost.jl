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

    properties (Constant)
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

                argstruct.host      (1,1) string = "localhost"
                argstruct.port      (1,1) int64 = 10000

                argstruct.timeout     (1,1) uint64 = 24*60*60*1000 % 1day
            end
            
            obj.id = uint64(randi(1e9, 'int32'));
            obj.host = argstruct.host;
            obj.port = argstruct.port;
            obj.timeout = argstruct.timeout;
            obj.project = argstruct.project;

            if isfield(argstruct, 'bindir')
                obj.julia = """" + fullfile(bindir, "julia.exe") + """";
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
            createstruct.cmdline = sprintf("%s %s ""%s"" ""%s"" %i", obj.julia, project_cmdline, bootstrap, obj.host, obj.port);
            
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
            [arguments, signature] = parseArguments( indexOp(end).Indices{:} );
            % This is the object being sent to MATLAB 
            callstruct.id = obj.id;
            callstruct.action = "CALL";
            callmeta.fully_qualified_name = join(fully_qualified_name_arr, ".");
            callmeta.signature = signature;
            callstruct.callstruct = {callmeta; arguments(:)};

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
                    throw(MException(v.id, "%s", v.message));
                else
                    throw(MException("matfrostjulia:error", v))
                end
            end

            function [args, signature] = parseArguments(varargin)
                % Elegant argument parsing using inputParser and validateSignature
                
                p = inputParser;p.KeepUnmatched=true;
                addParameter(p, 'signature', [], @(x) validateSignature(x));
                firstParameter = find(cellfun(@(x) isstring(x)&&isscalar(x)&&any(ismember(x,string(p.Parameters))), varargin),1);
                if isempty(firstParameter)
                    args = varargin; signature = [];
                else
                    parse(p, varargin{firstParameter:end});
                    args = varargin(1:firstParameter-1);
                    if validateSignature(p.Results.signature,numel(args))
                        signature = p.Results.signature;
                    end
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
