classdef HDF5Backend < pipeline.storage.StorageBackend
    % HDF5BACKEND HDF5-based implementation of StorageBackend interface
    % This class provides persistent storage operations using HDF5 files.
    % It implements all methods required by the StorageBackend interface.
    %
    % Usage:
    %   backend = pipeline.storage.HDF5Backend(filepath)
    %   backend.save('key1', data)
    %   data = backend.load('key1')
    %   tf = backend.exists('key1')
    %   backend.delete('key1')
    %
    % Error Handling:
    %   - Throws 'StorageBackend:InitializationFailed' for file creation issues
    %   - Throws 'StorageBackend:KeyNotFound' for missing keys
    %   - Throws 'StorageBackend:InvalidKey' for invalid key formats
    %   - Throws 'StorageBackend:SaveFailed' for save operation failures
    %   - Throws 'StorageBackend:LoadFailed' for load operation failures
    %   - Throws 'StorageBackend:DeleteFailed' for delete operation failures
    %
    % See Also: pipeline.storage.StorageBackend, pipeline.storage.StorageManager
    
    % Copyright 2025 The Framework Authors
    
    properties (Access = private)
        filepath    % Path to the HDF5 file
        logger      % Logger instance for debugging and error reporting
    end
    
    methods
        
        function obj = HDF5Backend(filepath)
            % CONSTRUCTOR Create HDF5Backend with specified file path
            %
            % Syntax:
            %   backend = HDF5Backend(filepath)
            %
            % Inputs:
            %   filepath - String or char array, path to HDF5 file
            %
            % Throws:
            %   'StorageBackend:InitializationFailed' if file cannot be created
            
            % Input validation
            if nargin < 1 || isempty(filepath)
                error('StorageBackend:InitializationFailed', ...
                    'Filepath is required for HDF5Backend');
            end
            
            % Convert to string and store
            obj.filepath = string(filepath);
            
            % Get the logger instance from the named singleton
            % The logger should have been initialized somewhere else
            obj.logger = mlog.Logger('pipeline:storage:backend:hdf5');
            
            try
                % Ensure the directory exists
                parent_dir = fileparts(char(obj.filepath));
                if ~isempty(parent_dir) && ~exist(parent_dir, 'dir')
                    [success, msg] = mkdir(parent_dir);
                    if ~success
                        error('Cannot create directory: %s', msg);
                    end
                end
                
                % Validate that we can write to the location
                % Try to create a temporary file first to test permissions
                try
                    temp_test_file = [char(obj.filepath), '.test'];
                    fid = fopen(temp_test_file, 'w');
                    if fid == -1
                        error('Cannot write to the specified location');
                    end
                    fclose(fid);
                    delete(temp_test_file);
                catch
                    error('Cannot write to the specified location');
                end
                
                % Test if we can create/access the file
                if ~exist(char(obj.filepath), 'file')
                    % Create the file by writing a dummy dataset and deleting it
                    h5create(char(obj.filepath), '/temp_init', [1 1]);
                    h5write(char(obj.filepath), '/temp_init', 1);
                    
                    % Remove the temporary dataset
                    file_id = H5F.open(char(obj.filepath), 'H5F_ACC_RDWR', 'H5P_DEFAULT');
                    H5L.delete(file_id, '/temp_init', 'H5P_DEFAULT');
                    H5F.close(file_id);
                end
                
                obj.logger.write(mlog.Level.INFO, ...
                    sprintf('HDF5Backend initialized with file: %s', obj.filepath));
                
            catch ME
                error('StorageBackend:InitializationFailed', ...
                    'Failed to initialize HDF5 file at %s: %s', ...
                    obj.filepath, ME.message);
            end
        end
        
        function save(obj, key, data)
            % SAVE Store data with the given key
            %
            % Syntax:
            %   save(backend, key, data)
            %
            % Inputs:
            %   key  - String or char array, unique identifier for the data
            %   data - Any MATLAB data to be stored
            %
            % Throws:
            %   'StorageBackend:InvalidKey' if the key is invalid
            %   'StorageBackend:SaveFailed' if the save operation fails
            
            % Validate key
            validated_key = obj.validateKey(key);
            dataset_path = obj.keyToDatasetPath(validated_key);
            
            try
                obj.logger.write(mlog.Level.DEBUG, ...
                    sprintf('Saving data to key: %s', validated_key));
                
                % Check if dataset already exists and delete it
                if obj.datasetExists(dataset_path)
                    obj.deleteDataset(dataset_path);
                end
                
                % Save the data based on its type
                obj.saveDataByType(dataset_path, data);
                
                obj.logger.write(mlog.Level.DEBUG, ...
                    sprintf('Successfully saved data to key: %s', validated_key));
                
            catch ME
                if strcmp(ME.identifier, 'StorageBackend:InvalidKey')
                    rethrow(ME);
                end
                error('StorageBackend:SaveFailed', ...
                    'Failed to save data to key "%s": %s', validated_key, ME.message);
            end
        end
        
        function data = load(obj, key)
            % LOAD Retrieve data for the given key
            %
            % Syntax:
            %   data = load(backend, key)
            %
            % Inputs:
            %   key - String or char array, unique identifier for the data
            %
            % Outputs:
            %   data - The stored MATLAB data
            %
            % Throws:
            %   'StorageBackend:KeyNotFound' if the key does not exist
            %   'StorageBackend:LoadFailed' if the load operation fails
            
            % Validate key
            validated_key = obj.validateKey(key);
            dataset_path = obj.keyToDatasetPath(validated_key);
            
            % Check if key exists
            if ~obj.datasetExists(dataset_path)
                error('StorageBackend:KeyNotFound', ...
                    'Key "%s" not found in storage', validated_key);
            end
            
            try
                obj.logger.write(mlog.Level.DEBUG, ...
                    sprintf('Loading data from key: %s', validated_key));
                
                % Load the data
                data = obj.loadDataByType(dataset_path);
                
                obj.logger.write(mlog.Level.DEBUG, ...
                    sprintf('Successfully loaded data from key: %s', validated_key));
                
            catch ME
                if strcmp(ME.identifier, 'StorageBackend:KeyNotFound')
                    rethrow(ME);
                end
                error('StorageBackend:LoadFailed', ...
                    'Failed to load data from key "%s": %s', validated_key, ME.message);
            end
        end
        
        function tf = exists(obj, key)
            % EXISTS Check if data exists for the given key
            %
            % Syntax:
            %   tf = exists(backend, key)
            %
            % Inputs:
            %   key - String or char array, unique identifier for the data
            %
            % Outputs:
            %   tf - Logical, true if the key exists, false otherwise
            
            try
                % Validate key
                validated_key = obj.validateKey(key);
                dataset_path = obj.keyToDatasetPath(validated_key);
                
                % Check if dataset exists
                tf = obj.datasetExists(dataset_path);
                
            catch
                % If key validation fails, it doesn't exist
                tf = false;
            end
        end
        
        function delete(obj, key)
            % DELETE Remove data for the given key
            %
            % Syntax:
            %   delete(backend, key)
            %
            % Inputs:
            %   key - String or char array, unique identifier for the data
            %
            % Throws:
            %   'StorageBackend:KeyNotFound' if the key does not exist
            %   'StorageBackend:DeleteFailed' if the delete operation fails
            
            % Validate key
            validated_key = obj.validateKey(key);
            dataset_path = obj.keyToDatasetPath(validated_key);
            
            % Check if key exists
            if ~obj.datasetExists(dataset_path)
                error('StorageBackend:KeyNotFound', ...
                    'Key "%s" not found in storage', validated_key);
            end
            
            try
                obj.logger.write(mlog.Level.DEBUG, ...
                    sprintf('Deleting data for key: %s', validated_key));
                
                obj.deleteDataset(dataset_path);
                
                obj.logger.write(mlog.Level.DEBUG, ...
                    sprintf('Successfully deleted data for key: %s', validated_key));
                
            catch ME
                if strcmp(ME.identifier, 'StorageBackend:KeyNotFound')
                    rethrow(ME);
                end
                error('StorageBackend:DeleteFailed', ...
                    'Failed to delete data for key "%s": %s', validated_key, ME.message);
            end
        end
        
    end
    
    methods (Access = private)
        
        function validated_key = validateKey(~, key)
            % Validate and sanitize the key for HDF5 storage
            if isempty(key) || (~ischar(key) && ~isstring(key))
                error('StorageBackend:InvalidKey', ...
                    'Key must be a non-empty string or char array');
            end
            
            validated_key = string(key);
            
            % Check for invalid characters (HDF5 specific)
            if contains(validated_key, '/')
                error('StorageBackend:InvalidKey', ...
                    'Key cannot contain forward slashes (reserved for HDF5 hierarchy)');
            end
            
            % Additional validation for HDF5 compatibility
            if strlength(validated_key) == 0
                error('StorageBackend:InvalidKey', ...
                    'Key cannot be empty');
            end
        end
        
        function dataset_path = keyToDatasetPath(~, key)
            % Convert a key to HDF5 dataset path
            dataset_path = sprintf('/data_%s', key);
        end
        
        function tf = datasetExists(obj, dataset_path)
            % Check if a dataset exists in the HDF5 file
            try
                file_id = H5F.open(char(obj.filepath), 'H5F_ACC_RDONLY', 'H5P_DEFAULT');
                
                % Use H5L.exists to check if link exists
                tf = logical(H5L.exists(file_id, dataset_path, 'H5P_DEFAULT'));
                
                H5F.close(file_id);
            catch
                tf = false;
            end
        end
        
        function saveDataByType(obj, dataset_path, data)
            % Save data to HDF5 based on its type
            if isstruct(data) || iscell(data) || islogical(data) || ~isreal(data) || isempty(data)
                % Use MATLAB's built-in save function for complex types
                temp_file = [tempname, '.mat'];
                save(temp_file, 'data', '-mat');
                
                % Read the .mat file as binary data
                fid = fopen(temp_file, 'rb');
                binary_data = fread(fid, '*uint8');
                fclose(fid);
                delete(temp_file);
                
                % Store as binary in HDF5 - handle empty data case
                if isempty(binary_data)
                    % Create with minimum size for empty data
                    h5create(char(obj.filepath), dataset_path, [1, 1]);
                    h5write(char(obj.filepath), dataset_path, uint8(0));
                else
                    h5create(char(obj.filepath), dataset_path, length(binary_data));
                    h5write(char(obj.filepath), dataset_path, binary_data);
                end
                
                % Store metadata to indicate this is MATLAB binary data
                h5writeatt(char(obj.filepath), dataset_path, 'matlab_type', 'binary');
            else
                % For numeric and char data, use direct HDF5 storage
                if ischar(data)
                    % Convert char to uint8 for storage
                    if isempty(data)
                        % Handle empty char
                        h5create(char(obj.filepath), dataset_path, [1, 1]);
                        h5write(char(obj.filepath), dataset_path, uint8(0));
                    else
                        data_to_store = uint8(data);
                        h5create(char(obj.filepath), dataset_path, size(data_to_store));
                        h5write(char(obj.filepath), dataset_path, data_to_store);
                    end
                    h5writeatt(char(obj.filepath), dataset_path, 'matlab_type', 'char');
                else
                    % For numeric data - handle empty case
                    if isempty(data)
                        % Store empty data as a special case
                        h5create(char(obj.filepath), dataset_path, [1, 1]);
                        h5write(char(obj.filepath), dataset_path, NaN);
                        h5writeatt(char(obj.filepath), dataset_path, 'matlab_type', 'empty');
                        h5writeatt(char(obj.filepath), dataset_path, 'original_class', class(data));
                    else
                        h5create(char(obj.filepath), dataset_path, size(data));
                        h5write(char(obj.filepath), dataset_path, data);
                        h5writeatt(char(obj.filepath), dataset_path, 'matlab_type', class(data));
                    end
                end
            end
        end
        
        function data = loadDataByType(obj, dataset_path)
            % Load data from HDF5 and convert to appropriate MATLAB type
            try
                % Check if there's type metadata
                matlab_type = h5readatt(char(obj.filepath), dataset_path, 'matlab_type');
                
                if strcmp(matlab_type, 'binary')
                    % This is MATLAB binary data, restore from .mat format
                    binary_data = h5read(char(obj.filepath), dataset_path);
                    
                    % Write to temporary .mat file and load
                    temp_file = [tempname, '.mat'];
                    fid = fopen(temp_file, 'wb');
                    fwrite(fid, binary_data, 'uint8');
                    fclose(fid);
                    
                    loaded = load(temp_file);
                    data = loaded.data;
                    delete(temp_file);
                    
                elseif strcmp(matlab_type, 'char')
                    % Convert back from uint8 to char
                    uint8_data = h5read(char(obj.filepath), dataset_path);
                    if isequal(uint8_data, uint8(0)) && numel(uint8_data) == 1
                        % This was an empty char
                        data = '';
                    else
                        data = char(uint8_data);
                    end
                    
                elseif strcmp(matlab_type, 'empty')
                    % This was empty data, restore original empty array
                    original_class = h5readatt(char(obj.filepath), dataset_path, 'original_class');
                    switch original_class
                        case 'double'
                            data = double.empty();
                        case 'single'
                            data = single.empty();
                        case 'logical'
                            data = logical.empty();
                        case 'char'
                            data = '';
                        otherwise
                            data = [];
                    end
                    
                else
                    % Load as stored type
                    data = h5read(char(obj.filepath), dataset_path);
                    
                    % Convert to the original MATLAB type
                    if ~strcmp(class(data), matlab_type)
                        switch matlab_type
                            case 'logical'
                                data = logical(data);
                            case 'double'
                                data = double(data);
                            case 'single'
                                data = single(data);
                            case 'int8'
                                data = int8(data);
                            case 'int16'
                                data = int16(data);
                            case 'int32'
                                data = int32(data);
                            case 'int64'
                                data = int64(data);
                            case 'uint8'
                                data = uint8(data);
                            case 'uint16'
                                data = uint16(data);
                            case 'uint32'
                                data = uint32(data);
                            case 'uint64'
                                data = uint64(data);
                        end
                    end
                end
                
            catch
                % Fallback: load as-is if no metadata available
                data = h5read(char(obj.filepath), dataset_path);
            end
        end
        
        function deleteDataset(obj, dataset_path)
            % Delete a dataset from the HDF5 file
            file_id = H5F.open(char(obj.filepath), 'H5F_ACC_RDWR', 'H5P_DEFAULT');
            H5L.delete(file_id, dataset_path, 'H5P_DEFAULT');
            H5F.close(file_id);
        end
        
    end
    
end
