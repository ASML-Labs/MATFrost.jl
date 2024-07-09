function mexdir = matfrostmexdir()

[~, juliaroot] = system('julia -e "print(Base.DEPOT_PATH[1])"');

mexdir = fullfile(juliaroot, "scratchspaces", "406cae98-a0f7-4766-b83f-8510a556e0e7", "mexbin");

end