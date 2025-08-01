function logLevel = stringToMlogLevel(levelStr)
    %stringToMlogLevel Converts a string to an mlog.Level enumeration.
    % Throws an error if the string is not a valid level.

    arguments
        levelStr (1,1) string
    end

    try
        logLevel = mlog.Level.(upper(levelStr));
    catch ME
        if strcmp(ME.identifier, 'MATLAB:subscripting:classHasNoPropertyOrMethod') || ...
           strcmp(ME.identifier, 'MATLAB:noSuchMethodOrField')
            error('pipeline:utility:InvalidLogLevel', ...
                  "'%s' is not a valid log level.", levelStr);
        else
            rethrow(ME);
        end
    end
end