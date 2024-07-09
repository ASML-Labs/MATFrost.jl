function bjlname = getmatfrostjuliacall(bindir)
% Get the name of the compiled mex file. If MEX file does not exist, it will compile. 
%
    bjlname = matfrostjuliacallname(bindir);
    if ~exist(bjlname, "file")
        mexdir = matfrostmexdir();
        matfrostmake(bindir, fullfile(mexdir, bjlname + ".mexw64"));
    end

end