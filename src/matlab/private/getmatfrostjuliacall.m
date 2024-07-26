function bjlname = getmatfrostjuliacall(juliaexe)
% Get the name of the compiled mex file. If MEX file does not exist, it will compile. 
%
    bjlname = matfrostjuliacallname(juliaexe);
    if ~exist(bjlname, "file")
        mexdir = matfrostmexdir(juliaexe);
        matfrostmake(juliaexe, fullfile(mexdir, bjlname + ".mexw64"));
    end

end