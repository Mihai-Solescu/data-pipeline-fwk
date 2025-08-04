classdef ConcurrentStorageDecorator < pipeline.storage.IStorageBackend
    %CONCURRENTSTORAGEDECORATOR Thread-safe wrapper for storage backends.
    %   This decorator implements the IStorageBackend interface and adds
    %   thread-safety to any backend implementation by serializing all
    %   access through an internal mutex. It is specifically designed to
    %   wrap the InMemoryBackend for use in parallel environments.
    %
    %   The decorator pattern allows the underlying backend to remain
    %   simple and focused while the concurrency concerns are handled
    %   separately in this wrapper.
    %
    % See Also: pipeline.storage.IStorageBackend, pipeline.storage.InMemoryBackend

    properties (Access = private)
        Backend    % The wrapped IStorageBackend instance
        LockFile   % File path used as a simple file-based mutex
        Logger     % mlog.Logger instance for this decorator
        LockTimeout % Timeout in seconds for acquiring lock
    end

    methods
        function obj = ConcurrentStorageDecorator(backend, logger)
            % CONSTRUCTOR Create thread-safe wrapper around a storage backend.
            %
            % Inputs:
            %   backend - (IStorageBackend) The backend to wrap
            %   logger  - (mlog.Logger) Logger instance for this decorator

            if nargin < 2 || ~isa(backend, 'pipeline.storage.IStorageBackend')
                error('pipeline:ConcurrentStorageDecorator:InvalidInput', ...
                    'Valid IStorageBackend instance and logger are required.');
            end

            obj.Backend = backend;
            obj.Logger = logger;
            obj.LockTimeout = 30; % 30 second timeout for lock acquisition
            
            % Create unique lock file path using temporary directory
            lockId = char(java.util.UUID.randomUUID());
            obj.LockFile = fullfile(tempdir, ['pipeline_lock_', lockId, '.tmp']);
            
            obj.Logger.info('pipeline:ConcurrentStorageDecorator:Initialized: ConcurrentStorageDecorator initialized with lock file: %s', obj.LockFile);
        end

        function write(obj, key, data)
            % WRITE Thread-safe write operation.
            %
            % Inputs:
            %   key  - (char) Unique identifier for the data
            %   data - (any) MATLAB variable to be stored

            obj.acquireLock();
            try
                obj.Backend.write(key, data);
                obj.Logger.debug('pipeline:ConcurrentStorageDecorator:WriteCompleted: Write operation completed for key: %s', char(key));
            catch ME
                obj.Logger.error('pipeline:ConcurrentStorageDecorator:WriteFailed: Write operation failed for key %s: %s', ...
                    char(key), ME.message);
                obj.releaseLock();
                rethrow(ME);
            end
            obj.releaseLock();
        end

        function data = read(obj, key)
            % READ Thread-safe read operation.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data
            %
            % Returns:
            %   data - The stored MATLAB variable

            obj.acquireLock();
            try
                data = obj.Backend.read(key);
                obj.Logger.debug('pipeline:ConcurrentStorageDecorator:ReadCompleted: Read operation completed for key: %s', char(key));
            catch ME
                obj.Logger.error('pipeline:ConcurrentStorageDecorator:ReadFailed: Read operation failed for key %s: %s', ...
                    char(key), ME.message);
                obj.releaseLock();
                rethrow(ME);
            end
            obj.releaseLock();
        end

        function flag = exists(obj, key)
            % EXISTS Thread-safe existence check.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data
            %
            % Returns:
            %   flag - (logical) True if the key exists, false otherwise

            obj.acquireLock();
            try
                flag = obj.Backend.exists(key);
                obj.Logger.debug('pipeline:ConcurrentStorageDecorator:ExistsCompleted: Exists check completed for key: %s', char(key));
            catch ME
                obj.Logger.error('pipeline:ConcurrentStorageDecorator:ExistsFailed: Exists check failed for key %s: %s', ...
                    char(key), ME.message);
                obj.releaseLock();
                rethrow(ME);
            end
            obj.releaseLock();
        end

        function remove(obj, key)
            % REMOVE Thread-safe remove operation.
            %
            % Inputs:
            %   key - (char) Unique identifier for the data to remove

            obj.acquireLock();
            try
                obj.Backend.remove(key);
                obj.Logger.debug('pipeline:ConcurrentStorageDecorator:RemoveCompleted: Remove operation completed for key: %s', char(key));
            catch ME
                obj.Logger.error('pipeline:ConcurrentStorageDecorator:RemoveFailed: Remove operation failed for key %s: %s', ...
                    char(key), ME.message);
                obj.releaseLock();
                rethrow(ME);
            end
            obj.releaseLock();
        end

        function backend = getBackend(obj)
            % GETBACKEND Returns the wrapped backend instance.
            %   This method is primarily for testing purposes to access
            %   backend-specific methods like getKeyCount() on InMemoryBackend.
            %
            % Returns:
            %   backend - (IStorageBackend) The wrapped backend instance

            backend = obj.Backend;
        end
    end

    methods (Access = private)
        function acquireLock(obj)
            % ACQUIRELOCK Acquires a file-based mutex.
            %   This method blocks until the lock file can be created exclusively.
            
            startTime = tic;
            while toc(startTime) < obj.LockTimeout
                try
                    % Try to create lock file exclusively
                    fid = fopen(obj.LockFile, 'w');
                    if fid ~= -1
                        fprintf(fid, '%d', feature('getpid')); % Write process ID
                        fclose(fid);
                        obj.Logger.debug('pipeline:ConcurrentStorageDecorator:LockAcquired: Lock acquired');
                        return;
                    end
                catch
                    % Lock file already exists or creation failed
                end
                
                % Wait a small amount before retrying
                pause(0.001); % 1ms
            end
            
            % Timeout reached
            error('pipeline:ConcurrentStorageDecorator:LockTimeout', ...
                'Failed to acquire lock within %d seconds', obj.LockTimeout);
        end

        function releaseLock(obj)
            % RELEASELOCK Releases the file-based mutex.
            
            try
                if exist(obj.LockFile, 'file')
                    delete(obj.LockFile);
                    obj.Logger.debug('pipeline:ConcurrentStorageDecorator:LockReleased: Lock released');
                end
            catch ME
                obj.Logger.warning('pipeline:ConcurrentStorageDecorator:LockReleaseFailed: Failed to release lock: %s', ME.message);
            end
        end
    end
end
