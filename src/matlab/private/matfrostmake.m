function matfrostmake(bindir, outmex)
% NOTE: MinGW-w64 should be installed separately.
% Environment variable: "MW_MINGW64_LOC" should point to the MinGW installation directory.
%
% Or see https://mathworks.com/help/matlab/matlab_external/install-mingw-support-package.html

arguments
    bindir (1,1) string {mustBeFolder}
    outmex (1,1) string %= fullfile(fileparts(mfilename('fullpath')), 'bin');
end
if ~isfolder(fileparts(outmex))
    mkdir(fileparts(outmex))
end

julia_dir = fileparts(bindir);

mex('-v', ...
    strcat('-I"', fullfile(julia_dir, 'include', 'julia'), '"'), ...
    strcat('"',   fullfile(julia_dir, 'lib', 'libjulia.dll.a'), '"'), ...
    strcat('"',   fullfile(julia_dir, 'lib', 'libopenlibm.dll.a'), '"'), ...
    '-output', outmex, ...
    fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'matfrostjuliacall', 'matfrostjuliacall.cpp'));

end
