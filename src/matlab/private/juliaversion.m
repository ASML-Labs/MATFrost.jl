function version = juliaversion(bindir)
%% Returns the version of the current or proivded julia executable
arguments
    bindir (1,1) string = ""
end
if ispc
    julia_exe = "julia.exe";
else
    julia_exe = "julia";
end
if bindir ~= "" && isfolder(bindir)
    julia_exe = fullfile(bindir, julia_exe);
end

[status, output] = system(sprintf('%s --version', julia_exe));
assert(~status, "matfrost:exe", "Count not run Julia in %s", bindir)
versionCell = regexp(output, 'julia version ([\d\.]+)', 'tokens');
version = versionCell{1}{1};

end
