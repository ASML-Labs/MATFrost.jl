function mexdir = matfrostmexdir(juliaexe)

env.PATH = fileparts(juliaexe);
env.LD_LIBRARY_PATH = fullfile(fileparts(fileparts(juliaexe)), "lib");

[~, juliaroot] = shell(juliaexe, '-e', 'print(Base.DEPOT_PATH[1])', environmentVariables=env);

mexdir = fullfile(juliaroot, "scratchspaces", "406cae98-a0f7-4766-b83f-8510a556e0e7", "mexbin");

end
