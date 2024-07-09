function p = matfrost_helloworld_environment()
    % Simple function which makes finding the path to the HelloWorld Julia environment easier.

    p = fullfile(fileparts(mfilename("fullpath")), "MATFrostHelloWorld.jl");
end
