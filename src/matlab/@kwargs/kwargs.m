classdef kwargs

    properties (SetAccess=immutable)
        Data struct
    end

    methods
        function obj = kwargs(varargin)
            if nargin == 0
                obj.Data = struct();
                return
            end

            if mod(nargin, 2) ~= 0
                error("Kwargs:InvalidInput", "Expected name/value pairs.");
            end

            data = struct();
            for k = 1:2:nargin
                key = varargin{k};
                if isstring(key) && isscalar(key)
                    name = char(key);
                elseif ischar(key)
                    name = key;
                else
                    error("Kwargs:InvalidName", "Keyword name at position %d must be a string scalar or char vector.", k);
                end

                if ~isvarname(name)
                    error("Kwargs:InvalidName", "Invalid Julia keyword argument name: %s", name);
                end

                data.(name) = varargin{k+1};
            end

            obj.Data = data;
        end
    end
end