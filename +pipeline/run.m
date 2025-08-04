function run(config)
    % Main entry point to the framework. Validates configuration,
    % builds the stage graph, and initializes the logging system.

    %% Initalization
    
    scriptFolder = fileparts(mfilename('fullpath')); % Get the folder of this script
    projectRoot = fullfile(scriptFolder, '..');      % Navigate to the project root
    addpath(genpath(projectRoot));                   % Add the project to the path

    currentDir = pwd; % Save current directory

    % Step 1: Initialize default logger immediately
    logger = mlog.Logger('pipeline:run');

    % Configure with hardcoded defaults (console output at INFO level)
    logger.CommandWindowThreshold = mlog.Level.INFO;

    logger.debug('pipeline:run:StartingPipeline: Starting pipeline execution with configuration from %s', mfilename('fullpath')); % Change initial log level to DEBUG if needed

    try
        % Step 2: Instantiate the validator
        validator = pipeline.utility.ConfigValidator(logger);
        
        % Step 3: Reconfigure logging
        try
            validator.validateLoggingConfig(config);
            logger.debug('pipeline:run:LoggingConfigValid: Logging configuration validated successfully.'); % Change initial log level to DEBUG if needed

            reconfigure_logger(logger, config, currentDir);
        catch ME
            logger.fatal('pipeline:run:LoggingConfigInvalid: Failed to reconfigure logging: %s', ME.message);
            rethrow(ME);
        end
        
        % Step 4: Perform basic validation (excluding the stage graph)
        try
            validator.validateBasicConfig(config);
            logger.debug('pipeline:run:BasicConfigValid: Basic configuration validated successfully.');
        catch ME
            logger.fatal('pipeline:run:BasicConfigInvalid: Basic configuration validation failed: %s', ME.message);
            rethrow(ME);
        end
        
        % Step 5: Build the stage graph
        stage_graph = pipeline.utility.StageGraph(config.stages, logger);
        % stage_graph.plot(); % Visually validate the stage graph structure
        
        % Step 6: Log successful initialization
        logger.info('pipeline:run:InitializationComplete: Pipeline initialization completed successfully.');

    catch ME
        logger.fatal('pipeline:run:InitializationFailed: Pipeline initialization failed: %s', ME.message);
        rethrow(ME);
    end

    %% Phase 1: Backwards Pass

    % Step 1: Initialize the ParameterManager and FileManager
    try
        parameter_manager = pipeline.ParameterManager(config, logger);
        logger.debug('pipeline:run:ParameterManagerInitialized: ParameterManager initialized successfully.');

        file_manager = pipeline.storage.FileManager(config.output_directory, logger);
        logger.debug('pipeline:run:FileManagerInitialized: FileManager initialized successfully.');
    catch ME
        logger.fatal('pipeline:run:ParameterManagerInitFailed: Failed to initialize ParameterManager: %s', ME.message);
        rethrow(ME);
    end

    % Step 2: 

end

function reconfigure_logger(logger, config, currentDir)
    % Reconfigure the logger based on the provided configuration.
    % Assumes filepath and file_level exist together, or not at all.

    if ~isfield(config, 'logging')
        return; % Nothing to do
    end

    % 1. Set the console log level
    if isfield(config.logging, 'console_level')
        console_level = pipeline.utility.stringToMlogLevel(config.logging.console_level);
        logger.CommandWindowThreshold = console_level;
    end

    % 2. Configure file logging (path and level together)
    if isfield(config.logging, 'filepath') && isfield(config.logging, 'file_level')
        % IMPORTANT: Create an absolute path from the provided currentDir
        absoluteLogPath = fullfile(currentDir, config.logging.filepath);
        logger.LogFile = absoluteLogPath;

        % Create the file if it doesn't exist
        if ~isfile(absoluteLogPath)
            [logDir, ~, ~] = fileparts(absoluteLogPath);
            if ~isempty(logDir) && ~isfolder(logDir)
                mkdir(logDir);
            end

            fid = fopen(absoluteLogPath, 'w');
            if fid ~= -1
                fclose(fid);
            else
                logger.warning('pipeline:run:LogFileCreateFailed: Could not create log file at %s. Check permissions.', absoluteLogPath);
            end
        end

        % Set the file log level
        file_level = pipeline.utility.stringToMlogLevel(config.logging.file_level);
        logger.FileThreshold = file_level;
    end
end