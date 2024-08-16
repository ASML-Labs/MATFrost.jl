function matfrostmake(juliaexe, mexdir, mjlname)
% NOTE: MinGW-w64 should be installed separately.
% Environment variable: "MW_MINGW64_LOC" should point to the MinGW installation directory.
%
% Or see https://mathworks.com/help/matlab/matlab_external/install-mingw-support-package.html

arguments
    juliaexe (1,1) string
    mexdir   (1,1) string
    mjlname  (1,1) string 
end
if ~isfolder(mexdir)
    mkdir(mexdir)
end

julia_dir = fileparts(fileparts(juliaexe));
if ispc
    mex('-v', ...
        strcat('-I"', fullfile(julia_dir, 'include', 'julia'), '"'), ...
        strcat('"',   fullfile(julia_dir, 'lib', 'libjulia.dll.a'), '"'), ...
        strcat('"',   fullfile(julia_dir, 'lib', 'libopenlibm.dll.a'), '"'), ...
        '-output', fullfile(mexdir, mjlname + ".mexw64"), ...
        fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'matfrostjuliacall', 'matfrostjuliacall.cpp'));
elseif isunix
    dir(fullfile(matlabroot(), "/sys/os/glnxa64/orig"))
    mex('-v', ...
        strcat('-I"', fullfile(julia_dir, 'include', 'julia'), '"'), ...
        strcat('"',   fullfile(julia_dir, 'lib', 'libjulia.so'), '"'), ...
        strcat('"', fullfile(matlabroot(), "/sys/os/glnxa64/orig/libstdc++.so.6"), '"'), ...
        '-output', fullfile(mexdir, mjlname + ".mexa64"), ...
        fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'matfrostjuliacall', 'matfrostjuliacall.cpp'));
    
    dir(fullfile(mexdir, mjlname + ".mexa64"))
end

end
