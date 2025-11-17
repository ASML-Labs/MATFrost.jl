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
        socket            (1,1) string
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

                argstruct.socket      (1,1) string = string(tempname) + ".sock"

                argstruct.timeout     (1,1) uint64 = 24*60*60*1000 % 1day
            end
            
            obj.id = uint64(randi(1e9, 'int32'));
            obj.socket = argstruct.socket;
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
            createstruct.socket = obj.socket;
            createstruct.timeout = obj.timeout;
            createstruct.cmdline = sprintf("%s %s ""%s"" ""%s""", obj.julia, project_cmdline, bootstrap, obj.socket);
            createstruct.socket = obj.socket;
            
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

            function [varargin, signature] = parseArguments(varargin)
                % Extracts 'signature' name-value pair if present, leaves other arguments untouched.
                signature = "";
                possibleKey = find(cellfun(@(x) ischar(x) || isstring(x), varargin));
                isKey = cellfun(@(x) isequal(x, "signature"),varargin(possibleKey));
                idx = possibleKey(find(isKey, 1, 'first'));
                if ~isempty(idx) && idx < numel(varargin)
                    signature = varargin{idx+1};
                    varargin(idx:idx+1) = [];
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
