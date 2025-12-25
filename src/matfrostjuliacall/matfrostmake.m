function matfrostmake(mjlname)
% NOTE: MinGW-w64 should be installed separately.
% Environment variable: "MW_MINGW64_LOC" should point to the MinGW installation directory.
%
% Or see https://mathworks.com/help/matlab/matlab_external/install-mingw-support-package.html

arguments
    mjlname  (1,1) string = "matfrostjuliacall"
end

% julia_dir = fileparts(fileparts(juliaexe));
if ispc
    mex("-setup:" + fullfile(matlabroot(), "bin", "win64", "mexopts","mingw64_g++.xml"), "C++")
    % mex('-setup', 'c++')
    mex('-v', ...
        "-L" + fullfile(getenv("MW_MINGW64_LOC"), "x86_64-w64-mingw32", "lib"),...
        '-lws2_32',...
        '-output', ...
        fullfile(fileparts(mfilename('fullpath')), "..", "matlab", "@matfrostjulia", "private", mjlname), ...
        fullfile(fileparts(mfilename('fullpath')), 'matfrostjuliacall.cpp'));
% elseif isunix
%     dir(fullfile(matlabroot(), "/sys/os/glnxa64/orig"))
%     mex('-v', ...
%         strcat('-I"', fullfile(julia_dir, 'include', 'julia'), '"'), ...
%         strcat('"',   fullfile(julia_dir, 'lib', 'libjulia.so'), '"'), ...
%         strcat('"', fullfile(matlabroot(), "/sys/os/glnxa64/orig/libstdc++.so.6"), '"'), ...
%         '-output', fullfile(mexdir, mjlname + ".mexa64"), ...
%         fullfile(fileparts(fileparts(fileparts(mfilename('fullpath')))), 'matfrostjuliacall', 'matfrostjuliacall.cpp'));
%     
%     dir(fullfile(mexdir, mjlname + ".mexa64"))
else
    error("Not supported yet!")
end

end
