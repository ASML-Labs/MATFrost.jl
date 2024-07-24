classdef matfrostjulia < matlab.mixin.indexing.RedefinesDot %& matlab.mixin.indexing.OverridesPublicDotMethodCall
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

    properties (Access=private)
        environment       (1,1) string
        namespace         (:,1) string = []
        bindir            (1,1) string
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
                argstruct.environment (1,1) string
                    % Julia environment.
            end
            
            % Check if environment is a relative path
            if isfolder(fullfile(pwd(), argstruct.environment))    
                argstruct.environment = fullfile(pwd(), argstruct.environment);
            
            % Check if environment is a system-wide environment. 
            elseif startsWith(argstruct.environment, "@")

            % Check if environment is an absolute path
            elseif ~isfolder(argstruct.environment)
                error("matfrostjulia:environment", "Can't find Julia environment");
            end

            obj.environment = argstruct.environment;

            if isfield(argstruct, 'bindir')
                obj.bindir = argstruct.bindir;
            elseif isfield(argstruct, 'version')
                obj.bindir = juliaup(argstruct.version);
            else
                [status, obj.bindir] = system('julia -e "print(Sys.BINDIR)"');
                assert(~status, "matfrostjulia:julia", ...
                        "Julia not found on PATH")
            end

            obj.matfrostjuliacall = getmatfrostjuliacall(obj.bindir);

            obj.mh = mexhost("EnvironmentVariables", [...
                "JULIA_PROJECT", obj.environment;
                "PATH",          obj.bindir]);
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


            callstruct.package        = char(ns(1));
            callstruct.function       = char(functionname);
            
            args = indexOp(end).Indices;
            
            jlo = obj.mh.feval(obj.matfrostjuliacall, callstruct, args{:});

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
