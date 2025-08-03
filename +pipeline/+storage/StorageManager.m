classdef StorageManager < handle
    % STORAGEMANAGER Orchestrates the two-tier (L1/L2) storage system.
    %   It is the single point of contact for the Executor and manages the
    %   flow of data between the fast in-memory cache (L1) and the slow
    %   persistent store (L2). Its public API is minimal, exposing only
    %   the core actions required by the execution engine.
    %
    % See Also: pipeline.storage.IStorageBackend

    properties (Access = private)
        L1_Cache % IStorageBackend for in-memory
        L2_Store % IStorageBackend for persistent
        Logger
    end

    methods
        function obj = StorageManager(l1_backend, l2_backend, logger)
            % CONSTRUCTOR Create StorageManager with L1 and L2 backends.
            %
            % Inputs:
            %   l1_backend - IStorageBackend implementation for L1 cache
            %   l2_backend - IStorageBackend implementation for L2 store
            %   logger     - mlog.Logger instance for logging operations

            if nargin < 3 || ~isa(l1_backend, 'pipeline.storage.IStorageBackend') || ~isa(l2_backend, 'pipeline.storage.IStorageBackend')
                error('pipeline:StorageManager:InvalidInput', 'Valid L1, L2 backends and a logger are required.');
            end
            
            obj.L1_Cache = l1_backend;
            obj.L2_Store = l2_backend;
            obj.Logger = logger;
            
            obj.Logger.info('pipeline:StorageManager:Initialized', 'StorageManager initialized.');
        end

        function data = load(obj, key)
            % LOAD Retrieves data, checking L1 then L2, and promoting if necessary.
            key = char(key);

            % 1. Check L1 cache
            if obj.L1_Cache.exists(key)
                obj.Logger.debug('pipeline:StorageManager:L1CacheHit', 'L1 cache hit for key: %s', key);
                data = obj.L1_Cache.read(key);
                return;
            end

            % 2. Check L2 persistent store
            if obj.L2_Store.exists(key)
                obj.Logger.info('pipeline:StorageManager:L2CacheHit', 'L2 cache hit for key: %s', key);
                data = obj.L2_Store.read(key);

                % 3. Promote to L1 for faster future access
                try
                    obj.L1_Cache.write(key, data);
                    obj.Logger.debug('pipeline:StorageManager:DataPromotedToL1', 'Promoted key to L1: %s', key);
                catch ME
                    % This can happen if L1 is immutable and the key somehow
                    % exists. This is a warning, not a fatal error, as we
                    % still have the data.
                    obj.Logger.warning('pipeline:StorageManager:PromotionFailed', ...
                        'Failed to promote data to L1 for key %s: %s', key, ME.message);
                end
                return;
            end

            % 4. Data not found anywhere
            msg = sprintf('Data not found in L1 or L2 for key: %s', key);
            obj.Logger.error('pipeline:StorageManager:DataNotFound', msg);
            error('pipeline:StorageManager:DataNotFound', msg);
        end

        function cache(obj, key, data)
            % CACHE Stores data only in the L1 in-memory cache.
            key = char(key);
            try
                obj.L1_Cache.write(key, data);
                obj.Logger.debug('pipeline:StorageManager:DataCachedToL1', 'Cached data to L1 for key: %s', key);
            catch ME
                obj.Logger.error('pipeline:StorageManager:CacheFailed', 'Failed to cache to L1 for key %s: %s', key, ME.message);
                rethrow(ME);
            end
        end

        function persist(obj, key)
            % PERSIST Promotes data from the L1 cache to the L2 persistent store.
            key = char(key);

            if ~obj.L1_Cache.exists(key)
                msg = sprintf('Cannot persist non-existent L1 key: %s', key);
                obj.Logger.error('pipeline:StorageManager:PersistRequestFailed', msg);
                error('pipeline:StorageManager:PersistRequestFailed', msg);
            end

            try
                data = obj.L1_Cache.read(key);
                obj.L2_Store.write(key, data);
                obj.Logger.debug('pipeline:StorageManager:DataPersistedToL2', 'Persisted data to L2 for key: %s', key);
            catch ME
                obj.Logger.error('pipeline:StorageManager:PersistFailed', 'Failed to persist to L2 for key %s: %s', key, ME.message);
                rethrow(ME);
            end
        end
    end
end