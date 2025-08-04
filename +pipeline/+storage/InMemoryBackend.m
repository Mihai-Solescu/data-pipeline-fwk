classdef InMemoryBackend < pipeline.storage.IStorageBackend
    %INMEMORYBACKEND Fast, volatile storage backend using MATLAB containers.Map.
    %   This backend implements the L1 in-memory cache using a containers.Map
    %   for fast data retrieval. Data is lost when the instance is destroyed
    %   or MATLAB is restarted. This backend is NOT thread-safe on its own
    %   and must be wrapped with ConcurrentStorageDecorator for parallel use.
    %
    % See Also: pipeline.storage.IStorageBackend, pipeline.storage.ConcurrentStorageDecorator

    properties (Access = private)
        DataStore % containers.Map for storing key-value pairs
        Logger    % mlog.Logger instance for this backend
    end

    methods
        function obj = InMemoryBackend(logger)
            % CONSTRUCTOR Create InMemoryBackend with empty data store.
            %
            % Inputs:
            %   logger - (mlog.Logger) Logger instance for this backend

            if nargin < 1
                error('pipeline:InMemoryBackend:InvalidInput', 'Logger is required.');
            end

            obj.DataStore = containers.Map('KeyType', 'char', 'ValueType', 'any');
            obj.Logger = logger;
            
            obj.Logger.info('pipeline:InMemoryBackend:Initialized: InMemoryBackend initialized with empty data store.');
        end

        function write(obj, key, data)
            % WRITE Stores data in the in-memory map.
            %
            % Inputs:
            %   key  - (char) Unique identifier for the data
            %   data - (any) MATLAB variable to be stored

            key = char(key);

            % Check if key already exists - prevent accidental overwrites
            if obj.DataStore.isKey(key)
                msg = sprintf('Attempted to overwrite existing key in memory: %s', key);
                obj.Logger.error('pipeline:InMemoryBackend:OverwriteAttempt: %s', msg);
                error('pipeline:InMemoryBackend:OverwriteAttempt', msg);
            end

            try
                obj.DataStore(key) = data;
                obj.Logger.debug('pipeline:InMemoryBackend:DataWritten: Successfully stored data for key: %s', key);
            catch ME
                obj.Logger.error('pipeline:InMemoryBackend:WriteFailed: Failed to write data for key %s: %s', ...
                    key, ME.message);
                rethrow(ME);
            end
        end

        function data = read(obj, key)
            % READ Retrieves data from the in-memory map.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data
            %
            % Returns:
            %   data - The stored MATLAB variable

            key = char(key);

            if ~obj.DataStore.isKey(key)
                msg = sprintf('Key not found in memory: %s', key);
                obj.Logger.error('pipeline:InMemoryBackend:ReadError: %s', msg);
                error('pipeline:InMemoryBackend:ReadError', msg);
            end

            try
                data = obj.DataStore(key);
                obj.Logger.debug('pipeline:InMemoryBackend:DataRead: Successfully retrieved data for key: %s', key);
            catch ME
                obj.Logger.error('pipeline:InMemoryBackend:ReadFailed: Failed to read data for key %s: %s', ...
                    key, ME.message);
                rethrow(ME);
            end
        end

        function flag = exists(obj, key)
            % EXISTS Checks if a key exists in the in-memory map.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data
            %
            % Returns:
            %   flag - (logical) True if the key exists, false otherwise

            key = char(key);
            flag = obj.DataStore.isKey(key);
            
            obj.Logger.debug('pipeline:InMemoryBackend:ExistenceCheck: Key %s exists: %s', key, string(flag));
        end

        function remove(obj, key)
            % REMOVE Deletes a key-value pair from the in-memory map.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data to remove

            key = char(key);

            if ~obj.DataStore.isKey(key)
                obj.Logger.warning('pipeline:InMemoryBackend:RemoveNonExistentKey: Attempted to remove non-existent key: %s', key);
                return;
            end

            try
                obj.DataStore.remove(key);
                obj.Logger.debug('pipeline:InMemoryBackend:KeyRemoved: Successfully removed key: %s', key);
            catch ME
                obj.Logger.error('pipeline:InMemoryBackend:RemoveFailed: Failed to remove key %s: %s', ...
                    key, ME.message);
                rethrow(ME);
            end
        end

        function count = getKeyCount(obj)
            % GETKEYCOUNT Returns the number of stored key-value pairs.
            %   This method is primarily for testing and debugging purposes.
            %
            % Returns:
            %   count - (double) Number of keys currently stored

            count = obj.DataStore.Count;
            obj.Logger.debug('pipeline:InMemoryBackend:KeyCountRequested: Current key count: %d', count);
        end

        function keys = getAllKeys(obj)
            % GETALLKEYS Returns all keys currently stored.
            %   This method is primarily for testing and debugging purposes.
            %
            % Returns:
            %   keys - (cell array of char) All keys currently in the store

            if obj.DataStore.Count == 0
                keys = {};
            else
                keys = obj.DataStore.keys();
            end
            obj.Logger.debug('pipeline:InMemoryBackend:AllKeysRequested: Returning %d keys', length(keys));
        end
    end
end
