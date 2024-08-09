function version = juliaversion(juliaexe)
%% Returns the version of the current or proivded julia executable
arguments
    juliaexe (1,1) string = ""
end

[status, output] = shell(juliaexe, '--version');
assert(~status, "matfrostjulia:exe", "Could not run Julia in %s", juliaexe)
versionCell = regexp(output, 'julia version ([\d\.]+)', 'tokens');
version = versionCell{1}{1};

end
