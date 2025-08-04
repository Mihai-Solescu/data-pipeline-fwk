classdef FileBackend < pipeline.storage.IStorageBackend
    %FILEBACKEND Persistent storage backend using individual .mat files.
    %   This backend implements the L2 persistent store using MATLAB's .mat
    %   file format. Each unique key corresponds to a single .mat file
    %   named after the key. The system is inherently thread-safe for writes
    %   because unique keys map to unique file paths.
    %
    %   Each .mat file contains three top-level variables:
    %   - outputs: The actual data payload from the computation
    %   - provenance: Static metadata about the computation's identity
    %   - telemetry: Historical performance metrics for this computation
    %
    % See Also: pipeline.storage.IStorageBackend, pipeline.storage.StorageManager

    properties (Access = private)
        OutputDirectory % Directory where .mat files are stored
        Logger          % mlog.Logger instance for this backend
    end

    methods
        function obj = FileBackend(output_directory, logger)
            % CONSTRUCTOR Create FileBackend with specified output directory.
            %
            % Inputs:
            %   output_directory - (char) Path to directory for .mat files
            %   logger          - (mlog.Logger) Logger instance for this backend

            if nargin < 2
                error('pipeline:FileBackend:InvalidInput', ...
                    'Output directory and logger are required.');
            end

            % Validate and create output directory if it doesn't exist
            output_directory = char(output_directory);
            if ~exist(output_directory, 'dir')
                try
                    mkdir(output_directory);
                    logger.info('pipeline:FileBackend:DirectoryCreated: Created output directory: %s', output_directory);
                catch ME
                    logger.error('pipeline:FileBackend:DirectoryCreationFailed: Failed to create directory %s: %s', ...
                        output_directory, ME.message);
                    rethrow(ME);
                end
            end

            obj.OutputDirectory = output_directory;
            obj.Logger = logger;
            
            obj.Logger.info('pipeline:FileBackend:Initialized: FileBackend initialized with directory: %s', output_directory);
        end

        function write(obj, key, data)
            % WRITE Persists data to a .mat file named after the key.
            %
            % The data structure written includes:
            % - outputs: The actual data payload
            % - provenance: Metadata about the computation
            % - telemetry: Performance metrics history
            %
            % Inputs:
            %   key  - (char) Unique identifier for the data
            %   data - (struct) Data structure with fields: outputs, provenance, telemetry

            key = char(key);
            filepath = obj.getFilePath(key);

            % Check if file already exists - prevent accidental overwrites
            if exist(filepath, 'file')
                msg = sprintf('Attempted to overwrite existing file for key: %s', key);
                obj.Logger.error('pipeline:FileBackend:OverwriteAttempt: %s', msg);
                error('pipeline:FileBackend:OverwriteAttempt', msg);
            end

            % Validate required data structure
            if ~isstruct(data) || ~isfield(data, 'outputs')
                msg = sprintf('Data must be a struct with at least an "outputs" field for key: %s', key);
                obj.Logger.error('pipeline:FileBackend:InvalidDataStructure: %s', msg);
                error('pipeline:FileBackend:InvalidDataStructure', msg);
            end

            % Prepare data structure for persistence
            outputs = data.outputs;
            
            % Set default provenance if not provided
            if isfield(data, 'provenance')
                provenance = data.provenance;
            else
                provenance = struct();
            end
            
            % Initialize telemetry if not provided
            if isfield(data, 'telemetry')
                telemetry = data.telemetry;
            else
                telemetry = {};
            end

            % Write to file with error handling
            try
                save(filepath, 'outputs', 'provenance', 'telemetry', '-mat');
                obj.Logger.debug('pipeline:FileBackend:DataWritten: Successfully wrote data to file: %s', filepath);
            catch ME
                obj.Logger.error('pipeline:FileBackend:WriteFailed: Failed to write data for key %s to file %s: %s', ...
                    key, filepath, ME.message);
                rethrow(ME);
            end
        end

        function data = read(obj, key)
            % READ Retrieves data from the .mat file corresponding to the key.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data
            %
            % Returns:
            %   data - (struct) Complete data structure with outputs, provenance, telemetry

            key = char(key);
            filepath = obj.getFilePath(key);

            if ~exist(filepath, 'file')
                msg = sprintf('File not found for key: %s (path: %s)', key, filepath);
                obj.Logger.error('pipeline:FileBackend:ReadError: %s', msg);
                error('pipeline:FileBackend:ReadError', msg);
            end

            try
                loaded = load(filepath, 'outputs', 'provenance', 'telemetry');
                
                % Reconstruct the data structure
                data = struct();
                data.outputs = loaded.outputs;
                data.provenance = loaded.provenance;
                data.telemetry = loaded.telemetry;
                
                obj.Logger.debug('pipeline:FileBackend:DataRead: Successfully read data from file: %s', filepath);
            catch ME
                obj.Logger.error('pipeline:FileBackend:ReadFailed: Failed to read data for key %s from file %s: %s', ...
                    key, filepath, ME.message);
                rethrow(ME);
            end
        end

        function flag = exists(obj, key)
            % EXISTS Checks if a .mat file exists for the given key.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data
            %
            % Returns:
            %   flag - (logical) True if the file exists, false otherwise

            key = char(key);
            filepath = obj.getFilePath(key);
            flag = exist(filepath, 'file') == 2; % 2 indicates a file (not directory)
            
            obj.Logger.debug('pipeline:FileBackend:ExistenceCheck: Key %s exists: %s', key, string(flag));
        end

        function remove(obj, key)
            % REMOVE Deletes the .mat file corresponding to the key.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data to remove

            key = char(key);
            filepath = obj.getFilePath(key);

            if ~exist(filepath, 'file')
                obj.Logger.warning('pipeline:FileBackend:RemoveNonExistentFile: Attempted to remove non-existent file for key: %s', key);
                return;
            end

            try
                delete(filepath);
                obj.Logger.debug('pipeline:FileBackend:FileRemoved: Successfully removed file: %s', filepath);
            catch ME
                obj.Logger.error('pipeline:FileBackend:RemoveFailed: Failed to remove file for key %s at path %s: %s', ...
                    key, filepath, ME.message);
                rethrow(ME);
            end
        end
    end

    methods (Access = private)
        function filepath = getFilePath(obj, key)
            % GETFILEPATH Constructs the full file path for a given key.
            %
            % Inputs:
            %   key - (char) Unique identifier
            %
            % Returns:
            %   filepath - (char) Full path to the .mat file

            % Sanitize key to ensure it's a valid filename
            sanitized_key = regexprep(key, '[^\w\-]', '_');
            filename = [sanitized_key, '.mat'];
            filepath = fullfile(obj.OutputDirectory, filename);
        end
    end
end
