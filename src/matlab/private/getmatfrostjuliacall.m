function mjlname = getmatfrostjuliacall(juliaexe)
% Get the name of the compiled mex file. If MEX file does not exist, it will compile. 
%
    mjlname = matfrostjuliacallname(juliaexe);
    if ~exist(mjlname, "file")
        mexdir = matfrostmexdir(juliaexe);
        matfrostmake(juliaexe, mexdir, mjlname);
    end

end