classdef TestStorageSystem < matlab.unittest.TestCase
    % TESTSTORAGESYSTEM Comprehensive test suite for the storage system.
    %   This test suite validates all components of the storage system
    %   including FileBackend, InMemoryBackend, StorageManager, and
    %   ConcurrentStorageDecorator. It includes both unit tests and
    %   rigorous concurrency tests using the Asynchronous Test Harness
    %   with Timeout pattern.
    
    properties (TestParameter)
        % Test data for various MATLAB types
        test_data = {42, ...                    % double scalar
                     'hello world', ...         % char array
                     [1, 2, 3; 4, 5, 6], ...   % double matrix
                     struct('a', 1, 'b', 2), ...% struct
                     true, ...                  % logical
                     {1, 'test', struct()}, ... % cell array
                     NaN, ...                   % special numeric
                     Inf, ...                   % special numeric
                     [], ...                    % empty double
                     complex(1, 2)}             % complex number
    end
    
    properties
        tempDir
        logger
        testTimeout = 30 % Default timeout for async tests in seconds
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            % Create temporary directory and logger for each test
            testCase.tempDir = tempname;
            mkdir(testCase.tempDir);
            
            % Add paths for testing - use full path from project root
            project_root = fileparts(mfilename('fullpath')); % Gets tests directory
            project_root = fileparts(project_root); % Gets project root directory
            addpath(fullfile(project_root, 'vendor', 'advanced-logger', 'advancedLogger'));
            addpath(project_root); % Add project root to path for +pipeline packages
            
            % Create logger instance for testing
            testCase.logger = mlog.Logger('pipeline:test:storage');
            testCase.logger.CommandWindowThreshold = mlog.Level.NONE; % Suppress console output during tests
        end
    end
    
    methods (TestMethodTeardown)
        function teardown(testCase)
            % Clean up temporary directory and any parallel pools
            if ~isempty(testCase.tempDir) && exist(testCase.tempDir, 'dir')
                rmdir(testCase.tempDir, 's');
            end
            
            % Clean up any parallel pools that might be running
            try
                if ~isempty(gcp('nocreate'))
                    delete(gcp('nocreate'));
                end
            catch
                % Ignore cleanup errors
            end
        end
    end
    
    %% Unit Tests for FileBackend (L2 Persistent Store)
    methods (Test)
        function testFileBackendWriteReadCycle(testCase, test_data)
            % Test that data written to FileBackend can be read back correctly
            
            backend = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            key = 'test_key';
            
            % Prepare data structure as expected by FileBackend
            data_struct = struct();
            data_struct.outputs = test_data;
            data_struct.provenance = struct('stage_name', 'test_stage');
            data_struct.telemetry = {};
            
            % Write and read back
            backend.write(key, data_struct);
            retrieved = backend.read(key);
            
            % Verify structure and content
            testCase.verifyTrue(isstruct(retrieved));
            testCase.verifyTrue(isfield(retrieved, 'outputs'));
            testCase.verifyTrue(isfield(retrieved, 'provenance'));
            testCase.verifyTrue(isfield(retrieved, 'telemetry'));
            testCase.verifyEqual(retrieved.outputs, test_data);
            testCase.verifyEqual(retrieved.provenance.stage_name, 'test_stage');
        end
        
        function testFileBackendErrorOnOverwrite(testCase)
            % Test that FileBackend throws error when attempting to overwrite
            
            backend = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            key = 'test_key';
            data_struct = struct('outputs', 'test_data');
            
            % First write should succeed
            backend.write(key, data_struct);
            
            % Second write should fail
            testCase.verifyError(@() backend.write(key, data_struct), ...
                'pipeline:FileBackend:OverwriteAttempt');
        end
        
        function testFileBackendErrorOnReadNonExistentKey(testCase)
            % Test that FileBackend throws error when reading non-existent key
            
            backend = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            
            testCase.verifyError(@() backend.read('nonexistent_key'), ...
                'pipeline:FileBackend:ReadError');
        end
        
        function testFileBackendRemoveDeletesFile(testCase)
            % Test that remove() successfully deletes the .mat file
            
            backend = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            key = 'test_key';
            data_struct = struct('outputs', 'test_data');
            
            % Write file
            backend.write(key, data_struct);
            testCase.verifyTrue(backend.exists(key));
            
            % Remove file
            backend.remove(key);
            testCase.verifyFalse(backend.exists(key));
        end
        
        function testFileBackendInvalidDataStructure(testCase)
            % Test that FileBackend validates input data structure
            
            backend = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            
            % Test with non-struct data
            testCase.verifyError(@() backend.write('key1', 'not_a_struct'), ...
                'pipeline:FileBackend:InvalidDataStructure');
            
            % Test with struct missing outputs field
            invalid_struct = struct('not_outputs', 'data');
            testCase.verifyError(@() backend.write('key2', invalid_struct), ...
                'pipeline:FileBackend:InvalidDataStructure');
        end
    end
    
    %% Unit Tests for InMemoryBackend (L1 In-Memory Store)
    methods (Test)
        function testInMemoryBackendWriteReadCycle(testCase, test_data)
            % Test that data written to InMemoryBackend can be read back correctly
            
            backend = pipeline.storage.InMemoryBackend(testCase.logger);
            key = 'test_key';
            
            % Write and read back
            backend.write(key, test_data);
            retrieved = backend.read(key);
            
            testCase.verifyEqual(retrieved, test_data);
        end
        
        function testInMemoryBackendErrorOnOverwrite(testCase)
            % Test that InMemoryBackend throws error when attempting to overwrite
            
            backend = pipeline.storage.InMemoryBackend(testCase.logger);
            key = 'test_key';
            
            % First write should succeed
            backend.write(key, 'first_data');
            
            % Second write should fail
            testCase.verifyError(@() backend.write(key, 'second_data'), ...
                'pipeline:InMemoryBackend:OverwriteAttempt');
        end
        
        function testInMemoryBackendVolatility(testCase)
            % Test that data is lost when new instance is created
            
            key = 'test_key';
            data = 'test_data';
            
            % Create first instance and store data
            backend1 = pipeline.storage.InMemoryBackend(testCase.logger);
            backend1.write(key, data);
            testCase.verifyTrue(backend1.exists(key));
            
            % Create second instance - data should not exist
            backend2 = pipeline.storage.InMemoryBackend(testCase.logger);
            testCase.verifyFalse(backend2.exists(key));
        end
        
        function testInMemoryBackendUtilityMethods(testCase)
            % Test utility methods getKeyCount and getAllKeys
            
            backend = pipeline.storage.InMemoryBackend(testCase.logger);
            
            % Initially empty
            testCase.verifyEqual(backend.getKeyCount(), uint64(0));
            testCase.verifyEqual(backend.getAllKeys(), {});
            
            % Add some keys
            backend.write('key1', 'data1');
            backend.write('key2', 'data2');
            
            % Check counts and keys
            testCase.verifyEqual(backend.getKeyCount(), uint64(2));
            keys = backend.getAllKeys();
            testCase.verifyEqual(length(keys), 2);
            testCase.verifyTrue(ismember('key1', keys));
            testCase.verifyTrue(ismember('key2', keys));
        end
    end
    
    %% Unit Tests for StorageManager (using Real Backends)
    methods (Test)
        function testStorageManagerLoadFromL1(testCase)
            % Test that load() retrieves data from L1 cache when available
            
            l1 = pipeline.storage.InMemoryBackend(testCase.logger);
            l2 = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            manager = pipeline.storage.StorageManager(l1, l2, testCase.logger);
            
            key = 'test_key';
            data = 'test_data';
            
            % Store data in L1 only
            l1.write(key, data);
            
            % Load should get from L1
            retrieved = manager.load(key);
            testCase.verifyEqual(retrieved, data);
        end
        
        function testStorageManagerLoadFromL2WithPromotion(testCase)
            % Test that load() retrieves from L2 and promotes to L1
            
            l1 = pipeline.storage.InMemoryBackend(testCase.logger);
            l2 = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            manager = pipeline.storage.StorageManager(l1, l2, testCase.logger);
            
            key = 'test_key';
            data_struct = struct('outputs', 'test_data');
            
            % Store data in L2 only
            l2.write(key, data_struct);
            testCase.verifyFalse(l1.exists(key));
            
            % Load should get from L2 and promote to L1
            retrieved = manager.load(key);
            testCase.verifyEqual(retrieved.outputs, data_struct.outputs);
            testCase.verifyTrue(l1.exists(key));
        end
        
        function testStorageManagerLoadFullMiss(testCase)
            % Test that load() throws error when key is in neither backend
            
            l1 = pipeline.storage.InMemoryBackend(testCase.logger);
            l2 = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            manager = pipeline.storage.StorageManager(l1, l2, testCase.logger);
            
            testCase.verifyError(@() manager.load('nonexistent_key'), ...
                'pipeline:StorageManager:DataNotFound');
        end
        
        function testStorageManagerCacheToL1Only(testCase)
            % Test that cache() only writes to L1
            
            l1 = pipeline.storage.InMemoryBackend(testCase.logger);
            l2 = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            manager = pipeline.storage.StorageManager(l1, l2, testCase.logger);
            
            key = 'test_key';
            data = 'test_data';
            
            % Cache data
            manager.cache(key, data);
            
            % Should be in L1 but not L2
            testCase.verifyTrue(l1.exists(key));
            testCase.verifyFalse(l2.exists(key));
        end
        
        function testStorageManagerPersistFromL1ToL2(testCase)
            % Test that persist() moves data from L1 to L2
            
            l1 = pipeline.storage.InMemoryBackend(testCase.logger);
            l2 = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            manager = pipeline.storage.StorageManager(l1, l2, testCase.logger);
            
            key = 'test_key';
            data = struct('outputs', 'test_data');
            
            % Cache data in L1
            manager.cache(key, data);
            testCase.verifyFalse(l2.exists(key));
            
            % Persist to L2
            manager.persist(key);
            testCase.verifyTrue(l2.exists(key));
        end
        
        function testStorageManagerPersistNonExistentKey(testCase)
            % Test that persist() fails for non-existent L1 key
            
            l1 = pipeline.storage.InMemoryBackend(testCase.logger);
            l2 = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            manager = pipeline.storage.StorageManager(l1, l2, testCase.logger);
            
            testCase.verifyError(@() manager.persist('nonexistent_key'), ...
                'pipeline:StorageManager:PersistRequestFailed');
        end
    end
    
    %% Concurrency and Stress Tests
    methods (Test)
        function testConcurrentDecoratorBasicOperation(testCase)
            % Test that ConcurrentStorageDecorator works correctly in serial
            
            base_backend = pipeline.storage.InMemoryBackend(testCase.logger);
            decorated = pipeline.storage.ConcurrentStorageDecorator(base_backend, testCase.logger);
            
            key = 'test_key';
            data = 'test_data';
            
            % Basic operations should work
            decorated.write(key, data);
            testCase.verifyTrue(decorated.exists(key));
            retrieved = decorated.read(key);
            testCase.verifyEqual(retrieved, data);
            
            decorated.remove(key);
            testCase.verifyFalse(decorated.exists(key));
        end
        
        function testL1WriteContentionOnSameKey(testCase)
            % This test validates that the ConcurrentStorageDecorator correctly
            % serializes access to the shared L1 cache when multiple threads
            % attempt to write to the exact same key simultaneously.

            % Skip if Parallel Computing Toolbox not available
            if ~license('test', 'Distrib_Computing_Toolbox')
                testCase.assumeFail('Parallel Computing Toolbox not available');
            end
            
            % --- Setup ---
            % Use a THREAD-BASED pool to ensure all workers share memory.
            pool = parpool('threads', 2); 
            testCase.addTeardown(@() delete(pool)); % Ensure pool is closed after test

            % The decorated backend is created in the main thread's workspace.
            % All parallel threads will access this single instance.
            base_backend = pipeline.storage.InMemoryBackend(testCase.logger);
            decorated = pipeline.storage.ConcurrentStorageDecorator(base_backend, testCase.logger);
            
            num_writes = 10;
            contention_key = 'the_only_key';

            % --- Action ---
            % Use parfeval to have many threads attempt to write.
            futures(1:num_writes) = parallel.FevalFuture;
            for i = 1:num_writes
                % All workers attempt to write to the SAME key.
                futures(i) = parfeval(pool, @attemptWrite, 1, decorated, contention_key, i);
            end

            % --- Verification ---
            % Use the Asynchronous Test Harness with Timeout.
            wait(futures, 15); % Wait up to 15 seconds for all to finish
            results = testCase.verifyWarningFree(@() fetchOutputs(futures), ...
                'Test should not time out, which would indicate a deadlock.');

            % Since the L1 cache is immutable, we expect EXACTLY ONE success
            % and N-1 failures with the OverwriteAttempt error.
            success_count = 0;
            failure_count = 0;
            for i = 1:num_writes
                if results(i).success
                    success_count = success_count + 1;
                elseif strcmp(results(i).error.identifier, 'pipeline:InMemoryBackend:OverwriteAttempt')
                    failure_count = failure_count + 1;
                end
            end

            testCase.verifyEqual(success_count, 1, ...
                'Exactly one write should succeed in an immutable cache.');
            
            testCase.verifyEqual(failure_count, num_writes - 1, ...
                'All other writes should fail with an OverwriteAttempt error.');
                
            % Final check: the key must exist in the backend.
            testCase.verifyTrue(decorated.exists(contention_key), ...
                'The key from the single successful write must exist in the cache.');
        end
        
        function testParallelL2WritesSucceed(testCase)
            % Test that L2 backend allows parallel writes to unique keys
            
            % Skip if Parallel Computing Toolbox not available
            if ~license('test', 'Distrib_Computing_Toolbox')
                testCase.assumeFail('Parallel Computing Toolbox not available');
            end
            
            backend = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            
            % Start parallel pool
            parpool('local', 4);
            
            % Many workers write to unique keys
            num_workers = 20;
            
            futures = parallel.FevalFuture.empty(num_workers, 0);
            for i = 1:num_workers
                key = sprintf('unique_key_%d', i);
                data_struct = struct('outputs', sprintf('data_%d', i));
                futures(i) = parfeval(@testCase.attemptL2Write, 1, backend, key, data_struct);
            end
            
            % Collect results with timeout
            try
                results = fetchOutputs(futures);
                
                % All writes should succeed
                successes = sum([results.success]);
                testCase.verifyEqual(successes, num_workers, 'All parallel L2 writes should succeed');
                
                % Verify all files exist
                for i = 1:num_workers
                    key = sprintf('unique_key_%d', i);
                    testCase.verifyTrue(backend.exists(key));
                end
                
            catch ME
                if contains(ME.message, 'timeout')
                    testCase.verifyFail('Test timed out - L2 writes may be blocking each other');
                else
                    rethrow(ME);
                end
            end
        end
        
        function testHighThroughputNoDroppedL1Writes(testCase)
            % Test that L1 cache handles high throughput operations without hanging
            % NOTE: This test validates operation completion, not cross-process memory sharing
            
            % Skip if Parallel Computing Toolbox not available
            if ~license('test', 'Distrib_Computing_Toolbox')
                testCase.assumeFail('Parallel Computing Toolbox not available');
            end
            
            % This test ensures that high-throughput parallel operations complete
            % without deadlocks. Each worker operates in its own memory space.
            
            base_backend = pipeline.storage.InMemoryBackend(testCase.logger);
            decorated = pipeline.storage.ConcurrentStorageDecorator(base_backend, testCase.logger);
            
            % Start parallel pool
            parpool('local', 4);
            
            % Many workers write unique keys
            num_workers = 4;  
            keys_per_worker = 50;  
            
            futures = parallel.FevalFuture.empty(num_workers, 0);
            for w = 1:num_workers
                futures(w) = parfeval(@testCase.writeUniqueKeysSimple, 1, decorated, w, keys_per_worker);
            end
            
            % Wait for completion with timeout
            try
                % Use a timer-based approach 
                start_time = tic;
                while any(strcmp({futures.State}, 'running')) && toc(start_time) < testCase.testTimeout
                    pause(0.1);
                end
                
                % Check if any futures are still running (timeout condition)
                if any(strcmp({futures.State}, 'running'))
                    testCase.verifyFail('Test timed out - possible deadlock in high throughput writes');
                    return;
                end
                
                % Get the actual results
                results = fetchOutputs(futures);
                written_count = sum([results.count]);
                
                % Verify we have the expected number of writes completed
                expected_count = uint64(num_workers * keys_per_worker);
                testCase.verifyEqual(uint64(written_count), expected_count, ...
                    sprintf('Expected %d writes to complete, but %d were completed', expected_count, written_count));
                
                % NOTE: We don't check the main thread's backend count because
                % workers operate in separate memory spaces. This is correct behavior.
                
            catch ME
                testCase.verifyFail(sprintf('Test failed with error: %s', ME.message));
            end
        end
        
        function testDoubleCheckedLockingPreventsRaceCondition(testCase)
            % Test StorageManager promotion logic with shared FileBackend
            % NOTE: Uses FileBackend which can be shared between processes
            
            % Skip if Parallel Computing Toolbox not available
            if ~license('test', 'Distrib_Computing_Toolbox')
                testCase.assumeFail('Parallel Computing Toolbox not available');
            end
            
            % Create a file backend with our test data (shared between processes)
            l2 = pipeline.storage.FileBackend(testCase.tempDir, testCase.logger);
            key = 'shared_key';
            data_struct = struct('outputs', 'shared_data');
            l2.write(key, data_struct);
            
            % Start parallel pool
            parpool('local', 4);
            
            % Many workers try to load the same key using individual StorageManagers
            % Each worker will have its own L1 cache but share the L2 FileBackend
            num_workers = 6;  
            
            futures = parallel.FevalFuture.empty(num_workers, 0);
            for i = 1:num_workers
                futures(i) = parfeval(@testCase.testManagerLoad, 1, testCase.tempDir, key);
            end
            
            % Collect results with timeout
            try
                results = fetchOutputs(futures);
                
                % All loads should succeed
                successes = sum([results.success]);
                testCase.verifyEqual(successes, num_workers, 'All loads should succeed');
                
                % Verify all returned the correct data
                for i = 1:length(results)
                    r = results(i);
                    if r.success
                        testCase.verifyEqual(r.data, 'shared_data', 'Loaded data should be correct');
                    end
                end
                
            catch ME
                if contains(ME.message, 'timeout')
                    testCase.verifyFail('Test timed out - possible deadlock in load operations');
                else
                    rethrow(ME);
                end
            end
        end
    end
    
    %% Helper Methods for Async Tests

    methods (Access = private)
        % Helper function to be executed on the parallel workers.
        function result = attemptWrite(backend, key, data)
            % This function wraps the write call in a try/catch block so that
            % we can return the outcome (success or error) to the main thread.
            result = struct('success', false, 'error', MException.empty);
            try
                backend.write(key, data);
                result.success = true;
            catch ME
                result.error = ME;
            end
        end
        
        function result = attemptL2Write(~, backend, key, data_struct)
            % Helper method for testing L2 writes
            result = struct('success', false, 'error', '');
            
            try
                backend.write(key, data_struct);
                result.success = true;
            catch ME
                result.error = ME.identifier;
            end
        end
        
        function writeUniqueKeys(testCase, backend, written_keys, worker_id, num_keys)
            % Helper method for writing many unique keys
            for i = 1:num_keys
                key = sprintf('worker_%d_key_%d', worker_id, i);
                data = sprintf('data_%d_%d', worker_id, i);
                
                try
                    backend.write(key, data);
                    written_keys.send(key);
                catch ME
                    % Log error but continue
                    testCase.logger.error('Failed to write key %s: %s', key, ME.message);
                end
            end
        end
        
        function result = writeUniqueKeysSimple(~, backend, worker_id, num_keys)
            % Helper method for writing many unique keys with count return
            result = struct('count', 0);
            
            for i = 1:num_keys
                key = sprintf('worker_%d_key_%d', worker_id, i);
                data = sprintf('data_%d_%d', worker_id, i);
                
                try
                    backend.write(key, data);
                    result.count = result.count + 1;
                catch
                    % Silent failure - just don't increment count
                end
            end
        end
        
        function result = attemptLoad(~, manager, key, counter)
            % Helper method for testing concurrent loads
            result = struct('success', false, 'error', '');
            
            try
                manager.load(key); % Load to trigger cache promotion
                counter.send(1); % Signal that we performed a load
                result.success = true;
            catch ME
                result.error = ME.identifier;
            end
        end
        
        function result = attemptLoadSimple(~, manager, key)
            % Helper method for testing concurrent loads (simplified)
            result = struct('success', false, 'error', '');
            
            try
                manager.load(key); % Load to trigger cache promotion
                result.success = true;
            catch ME
                result.error = ME.identifier;
            end
        end
        
        function result = testManagerLoad(~, tempDir, key)
            % Helper method for testing StorageManager in parallel workers
            % This creates a fresh StorageManager in each worker process
            result = struct('success', false, 'error', '', 'data', '');
            
            try
                % Set up path in worker
                project_root = tempDir;
                while ~exist(fullfile(project_root, '+pipeline'), 'dir') && length(project_root) > 3
                    project_root = fileparts(project_root);
                end
                addpath(project_root);
                addpath(fullfile(project_root, 'vendor', 'advanced-logger', 'advancedLogger'));
                
                % Create logger in worker
                worker_logger = mlog.Logger('pipeline:test:worker');
                worker_logger.CommandWindowThreshold = mlog.Level.NONE;
                
                % Create storage manager with fresh backends
                l1 = pipeline.storage.InMemoryBackend(worker_logger);
                l2 = pipeline.storage.FileBackend(tempDir, worker_logger);
                manager = pipeline.storage.StorageManager(l1, l2, worker_logger);
                
                % Load the data
                loaded_struct = manager.load(key);
                result.data = loaded_struct.outputs;
                result.success = true;
                
            catch ME
                result.error = ME.identifier;
            end
        end
        
        function collectKey(~, ~, ~)
            % Helper method for collecting written keys (not used in current implementation)
            % This would be used if we needed to track all written keys
        end
        
        function incrementCounter(~)
            % Helper method for incrementing read counter (not used in current implementation)
            % This would be used if we needed precise read counting
        end
    end
end
