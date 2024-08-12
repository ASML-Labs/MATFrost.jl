function [exitCode, stdOut] = shell(varargin, options)
    % Executes a system command and returns the standard output.
    %
    % This function uses Java's ProcessBuilder to execute the command. This has the befenit that
    % live stdout are piped to the MATLAB console. This is not possible with the system function.
    
    arguments (Repeating)
        varargin char
    end
    arguments
        options.executionDirectory (1,1) string = pwd               % Directory to execute the command
        options.environmentVariables (1,1) struct = struct()        % Environment variables to give to the command
        options.echo (1,1) logical = false                          % Whether to echo the stdout in the cmd
        options.loggingFilter (1,:) string = string.empty(1,0)      % Whether to filter the logging
    end

    import java.io.*
    import java.lang.*
    
    builder = ProcessBuilder(varargin);
    builder.redirectErrorStream(true);
    builder.directory(File(options.executionDirectory));

    variableNames = fieldnames(options.environmentVariables);
    if ~isempty(variableNames)
        environment = builder.environment();
        for iVar = 1:numel(variableNames)
            environment.put(variableNames{iVar}, options.environmentVariables.(variableNames{iVar}));
        end
    end
    process = builder.start();
    reader = BufferedReader(InputStreamReader(process.getInputStream()));
    
    stdOut = "";
    while true
        nextLine = reader.readLine();
        if isa(nextLine, 'java.lang.String')
            line = string(nextLine.toString());
            if isempty(options.loggingFilter) || contains(line, options.loggingFilter)
                stdOut = stdOut + line + newline;
                if options.echo
                    fprintf("%s\n", line);
                end
            end
        else
            break
        end
    end

    stdOut = strip(stdOut);
    exitCode = process.waitFor();
end