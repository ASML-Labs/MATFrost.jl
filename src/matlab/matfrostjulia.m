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
        environment       (1,1) string = fullfile(fileparts(fileparts(mfilename("fullpath"))), "{{ relative_environment }}")
        julia             (1,1) string
    end

    properties (Access=private)
        namespace         (:,1) string = []
        matfrostjuliacall (1,1) string
        mh                     matlab.mex.MexHost
    end

    methods
        function obj = matfrostjulia(argstruct)
            arguments                
                argstruct.version     (1,1) string
                    % The version of Julia to use. i.e. 1.10 (Juliaup channel)
                argstruct.bindir      (1,1) string {mustBeFolder}
                    % The directory where the Julia environment is located.
                    % This will overrule the version specification.
                    % NOTE: Only needed if version is not specified.
                argstruct.instantiate (1,1) logical = false
                    % Resolve project environment
            end
            
            if isfield(argstruct, 'bindir')
                bindir = argstruct.bindir;
            elseif isfield(argstruct, 'version')
                bindir = juliaup(argstruct.version);
            else
                [status, bindir] = shell('julia', '-e', 'print(Sys.BINDIR)');
                assert(~status, "matfrostjulia:julia", ...
                        "Julia not found on PATH")
            end

            if ispc
                obj.julia = fullfile(bindir, "julia.exe");
            elseif isunix
                error("matfrostjulia:osNotSupported", "Linux not supported yet.");
                % obj.julia = fullfile(bindir, "julia");
            else
                error("matfrostjulia:osNotSupported", "MacOS not supported yet.");
            end

            if argstruct.instantiate
                environmentinstantiate(obj.julia, obj.environment);
            end
            
            matv = regexp(version, "R20\d\d[ab]", "match");
            matv = matv{1};
            obj.matfrostjuliacall = "matfrostjuliacall_r" + string(matv(2:end));
            
            
            obj.spawn_mexhost();


        end
    end

    methods (Access=private)
        function obj = spawn_mexhost(obj)
            if ispc
                obj.mh = mexhost("EnvironmentVariables", [...
                    "JULIA_PROJECT", obj.environment;
                    "PATH",          fileparts(obj.julia)]);
            elseif isunix
                obj.mh = mexhost("EnvironmentVariables", [...
                    "JULIA_PROJECT",   obj.environment;
                    "PATH",            fileparts(obj.julia); 
                    "LD_LIBRARY_PATH", fullfile(fileparts(fileparts(obj.julia)), "lib")]);
            end
        end
    end
   
    methods (Access=protected)
        function varargout = dotReference(obj,indexOp)
            % Calls into the loaded julia package.
            
            if indexOp(end).Type ~= matlab.indexing.IndexingOperationType.Paren
                 for i = 1:length(indexOp)
                    obj.namespace(end+1) = indexOp(i).Name; 
                 end
                varargout{1} = obj;
                return;
            end
            
            ns = obj.namespace;
            for i = 1:(length(indexOp)-2)
                ns(end+1) = indexOp(i).Name; 
            end
            
            functionname = indexOp(end-1).Name;


            args = indexOp(end).Indices;

            callstruct.package = string(ns(1));
            callstruct.func    = string(functionname);
            callstruct.args    = args(:);

            try
                jlo = obj.mh.feval(obj.matfrostjuliacall, callstruct);
            catch ME
                if (strcmp(ME.identifier, "MATLAB:mex:MexHostCrashed"))
                    obj.spawn_mexhost();
                end
                rethrow(ME)
            end

            varargout{1} = jlo;
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
