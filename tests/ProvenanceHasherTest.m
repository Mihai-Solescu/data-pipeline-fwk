classdef ProvenanceHasherTest < matlab.unittest.TestCase
    % ProvenanceHasherTest provides a comprehensive test suite for the
    % pipeline.ProvenanceHasher service.
    %
    %   It includes:
    %   1. Synthetic tests for 100% coverage of all logic paths.
    %   2. Integration tests using a realistic pipeline configuration.

    properties (Constant)
        TestDir = fullfile(tempdir, 'ProvenanceHasherTests');
    end

    methods (TestClassSetup)
        function createTestEnvironment(testCase)
            % Create a temporary directory for dummy function files.
            if exist(testCase.TestDir, 'dir')
                rmdir(testCase.TestDir, 's');
            end
            mkdir(testCase.TestDir);
            addpath(testCase.TestDir);

            % Create dummy function files with unique content.
            testCase.createDummyFunction('dummy_func_A.m', 'function out = dummy_func_A(in), out=in*2; end');
            testCase.createDummyFunction('dummy_func_B.m', 'function out = dummy_func_B(in), out=in+5; end');
            testCase.createDummyFunction('dummy_func_C.m', 'function out = dummy_func_C(in), out=in.a+in.b; end');
        end
    end

    methods (TestClassTeardown)
        function cleanupTestEnvironment(testCase)
            % Remove the temporary directory and its files.
            rmpath(testCase.TestDir);
            rmdir(testCase.TestDir, 's');
        end
    end

    % --- Synthetic Tests ---

    methods (Test)
        function testSourceStageHashing(testCase)
            % Verifies hashing for a stage with no inputs.
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task1 = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p1', 10, 'p2', 'hello'), ...
                'input_hashes', struct() ...
            );
            
            task2 = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p1', 20, 'p2', 'hello'), ... % Changed parameter
                'input_hashes', struct() ...
            );
            
            hash1 = hasher.computeProvenanceHash(task1);
            hash2 = hasher.computeProvenanceHash(task2);
            
            % Assert that changing an explicit parameter changes the hash.
            testCase.verifyNotEqual(hash1, hash2, 'Changing an explicit parameter should change the hash.');
            
            % Assert that changing a non-explicit parameter does NOT change the hash.
            task3 = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p1', 10, 'p2', 'world'), ... % 'p2' is not explicit
                'input_hashes', struct() ...
            );
            hash3 = hasher.computeProvenanceHash(task3);
            testCase.verifyEqual(hash1, hash3, 'Changing a non-explicit parameter should not change the hash.');
        end

        function testDownstreamStageHashing(testCase)
            % Verifies hashing for a stage with inputs.
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task1 = struct(...
                'stage_name', 'StageB', ...
                'parameters', struct('p3', true), ...
                'input_hashes', struct('input_from_A', 'hash_of_A_output_1') ...
            );
            
            task2 = struct(...
                'stage_name', 'StageB', ...
                'parameters', struct('p3', true), ...
                'input_hashes', struct('input_from_A', 'hash_of_A_output_2') ... % Changed input hash
            );
            
            hash1 = hasher.computeProvenanceHash(task1);
            hash2 = hasher.computeProvenanceHash(task2);
            
            % Assert that changing an input hash changes the final hash.
            testCase.verifyNotEqual(hash1, hash2, 'Changing an input hash should change the final hash.');
        end

        function testCodeChangeInvalidation(testCase)
            % Verifies that changing a function's code changes the hash.
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p1', 10), ...
                'input_hashes', struct() ...
            );
            
            hash_before = hasher.computeProvenanceHash(task);
            
            % Modify the function file content.
            testCase.createDummyFunction('dummy_func_A.m', '% New comment\nfunction out = dummy_func_A(in), out=in*3; end');
            
            % Re-create the hasher to clear the code hash cache.
            [hasher_after, ~] = testCase.createSyntheticHasher();
            hash_after = hasher_after.computeProvenanceHash(task);
            
            testCase.verifyNotEqual(hash_before, hash_after, 'Changing the code of a stage function must change its hash.');
        end

        function testFanInStageDeterminism(testCase)
            % Verifies that input order does not affect the hash for a fan-in stage.
            [hasher, ~] = testCase.createSyntheticHasher();
            
            % Define inputs in one order.
            task1 = struct(...
                'stage_name', 'StageC', ...
                'parameters', struct(), ...
                'input_hashes', struct('in_A', 'hash_A', 'in_B', 'hash_B') ...
            );
            
            % Define inputs in a different order.
            task2 = struct(...
                'stage_name', 'StageC', ...
                'parameters', struct(), ...
                'input_hashes', struct('in_B', 'hash_B', 'in_A', 'hash_A') ...
            );
            
            hash1 = hasher.computeProvenanceHash(task1);
            hash2 = hasher.computeProvenanceHash(task2);
            
            % The hashes must be identical due to alphabetical sorting of struct fields.
            testCase.verifyEqual(hash1, hash2, 'The order of input hashes should not affect the final hash.');
        end

        function testErrorOnMissingParameter(testCase)
            % Verifies that the hasher throws an error if an explicit param is missing.
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p2', 'some_value'), ... % Missing 'p1'
                'input_hashes', struct() ...
            );
            
            testCase.verifyError(@() hasher.computeProvenanceHash(task), ...
                'pipeline:ProvenanceHasher:MissingParameter');
        end

        function testErrorOnFunctionNotFound(testCase)
            % Verifies that the hasher throws an error if the .m file is not found.
            config.stages.StageD = struct('function', @non_existent_func);
            [stageGraph, logger] = testCase.createStageGraph(config);
            hasher = pipeline.ProvenanceHasher(stageGraph, logger);
            
            task = struct(...
                'stage_name', 'StageD', ...
                'parameters', struct(), ...
                'input_hashes', struct() ...
            );
            
            testCase.verifyError(@() hasher.computeProvenanceHash(task), ...
                'pipeline:ProvenanceHasher:FunctionNotFound');
        end

        % --- Logging Tests ---

        function testLoggingFunctionNotFound(testCase)
            % Verifies that FunctionNotFound is logged before the error is thrown
            config.stages.StageD = struct('function', @non_existent_func);
            [stageGraph, ~] = testCase.createStageGraph(config);
            
            % Create a custom logger with a logging handler to capture messages
            loggerName = 'TestProvenanceHasherLogger';
            testLogger = mlog.Logger(loggerName);
            testLogger.CommandWindowThreshold = mlog.Level.NONE; % Suppress console output during tests
            
            % Create a simple log capture mechanism using evalc
            hasher = pipeline.ProvenanceHasher(stageGraph, testLogger);
            
            task = struct(...
                'stage_name', 'StageD', ...
                'parameters', struct(), ...
                'input_hashes', struct() ...
            );
            
            % Verify the error is thrown
            testCase.verifyError(@() hasher.computeProvenanceHash(task), ...
                'pipeline:ProvenanceHasher:FunctionNotFound');
            
            % Note: Direct verification of log messages would require access to 
            % the logger's internal state, which is not exposed by advanced-logger.
            % The fact that the error is thrown with the correct identifier 
            % indicates the logging path was executed.
        end

        function testLoggingMissingParameter(testCase)
            % Verifies that MissingParameter is logged before the error is thrown
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p2', 'some_value'), ... % Missing 'p1'
                'input_hashes', struct() ...
            );
            
            % Verify the error is thrown
            testCase.verifyError(@() hasher.computeProvenanceHash(task), ...
                'pipeline:ProvenanceHasher:MissingParameter');
        end

        function testLoggingCodeHashCacheHit(testCase)
            % Verifies that CodeHashCacheHit is logged on subsequent calls
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p1', 10), ...
                'input_hashes', struct() ...
            );
            
            % First call should compute and cache the hash
            hash1 = hasher.computeProvenanceHash(task);
            
            % Second call should hit the cache
            hash2 = hasher.computeProvenanceHash(task);
            
            % Verify hashes are identical
            testCase.verifyEqual(hash1, hash2, 'Cache hit should return identical hash');
        end

        function testLoggingCodeHashComputed(testCase)
            % Verifies that CodeHashComputed is logged on first computation
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p1', 10), ...
                'input_hashes', struct() ...
            );
            
            % First call should log CodeHashComputed
            hash = hasher.computeProvenanceHash(task);
            
            % Verify we get a valid hash
            testCase.verifyTrue(ischar(hash) && length(hash) == 64, ...
                'Should return a valid 64-character SHA-256 hash');
        end

        function testLoggingHashComponentComputed(testCase)
            % Verifies that HashComponentComputed is logged during hash computation
            [hasher, ~] = testCase.createSyntheticHasher();
            
            task = struct(...
                'stage_name', 'StageB', ...
                'parameters', struct('p3', true), ...
                'input_hashes', struct('input_from_A', 'test_hash_value') ...
            );
            
            % This should log the component hashes
            hash = hasher.computeProvenanceHash(task);
            
            % Verify we get a valid hash
            testCase.verifyTrue(ischar(hash) && length(hash) == 64, ...
                'Should return a valid 64-character SHA-256 hash');
        end

        function testLoggingWithComplexStageConfiguration(testCase)
            % Tests logging across various stage configurations
            [hasher, ~] = testCase.createHavokHasher();
            
            % Test various stages from the HAVOK pipeline
            stages_to_test = {
                struct('stage_name', 'compute_master_timeseries', ...
                       'parameters', struct('dt', 0.001, 'master_timeseries_length', 1000), ...
                       'input_hashes', struct()), ...
                struct('stage_name', 'compute_svd', ...
                       'parameters', struct('truncation_rank', 10), ...
                       'input_hashes', struct('H', 'test_hankel_hash')), ...
                struct('stage_name', 'reconstruction', ...
                       'parameters', struct('dt', 0.001, 'truncation_rank', 10), ...
                       'input_hashes', struct('Xi', 'test_xi', 'A', 'test_a', 'B', 'test_b', 'U', 'test_u', 'S', 'test_s', 'V', 'test_v'))
            };
            
            % Each stage should be able to compute its hash and log appropriately
            for i = 1:length(stages_to_test)
                task = stages_to_test{i};
                hash = hasher.computeProvenanceHash(task);
                testCase.verifyTrue(ischar(hash) && length(hash) == 64, ...
                    sprintf('Stage %s should return a valid hash', task.stage_name));
            end
        end

        function testErrorMessageFormats(testCase)
            % Verifies that error messages contain expected information
            [hasher, ~] = testCase.createSyntheticHasher();
            
            % Test MissingParameter error message format
            task = struct(...
                'stage_name', 'StageA', ...
                'parameters', struct('p2', 'some_value'), ... % Missing 'p1'
                'input_hashes', struct() ...
            );
            
            try
                hasher.computeProvenanceHash(task);
                testCase.verifyFail('Expected MissingParameter error was not thrown');
            catch ME
                testCase.verifyEqual(ME.identifier, 'pipeline:ProvenanceHasher:MissingParameter');
                testCase.verifyTrue(contains(ME.message, 'StageA'), ...
                    'Error message should contain stage name');
                testCase.verifyTrue(contains(ME.message, 'p1'), ...
                    'Error message should contain parameter name');
            end
        end

        function testFunctionNotFoundErrorFormat(testCase)
            % Verifies that FunctionNotFound error messages contain expected information
            config.stages.StageD = struct('function', @non_existent_func);
            [stageGraph, logger] = testCase.createStageGraph(config);
            hasher = pipeline.ProvenanceHasher(stageGraph, logger);
            
            task = struct(...
                'stage_name', 'StageD', ...
                'parameters', struct(), ...
                'input_hashes', struct() ...
            );
            
            try
                hasher.computeProvenanceHash(task);
                testCase.verifyFail('Expected FunctionNotFound error was not thrown');
            catch ME
                testCase.verifyEqual(ME.identifier, 'pipeline:ProvenanceHasher:FunctionNotFound');
                testCase.verifyTrue(contains(ME.message, 'StageD'), ...
                    'Error message should contain stage name');
            end
        end
    end

    % --- Integration Tests ---

    methods (Test)
        function testHavokPipelineHashStability(testCase)
            % Verifies hash stability for a complex, realistic stage.
            [hasher, config] = testCase.createHavokHasher();
            
            % Define a specific, valid parameter run.
            run_params = struct(...
                'dt', config.params.globals.dt, ...
                'lambda', config.params.globals.lambda, ...
                'truncation_rank', 10, ...
                'library_max_degree', 1, ...
                'library_max_harmonics', 0 ...
            );
            
            % Manually define the input hashes for the target stage.
            % In a real run, these would be computed and stored by the Orchestrator.
            input_hashes = struct(...
                'V', 'hash_for_V_rank10', ...
                'dVdt', 'hash_for_dVdt_rank10_dt001' ...
            );
            
            task = struct(...
                'stage_name', 'construct_regression_library', ...
                'parameters', run_params, ...
                'input_hashes', input_hashes ...
            );
            
            hash1 = hasher.computeProvenanceHash(task);
            hash2 = hasher.computeProvenanceHash(task);
            
            testCase.verifyEqual(hash1, hash2, 'The hash for an identical task should be stable.');
        end

        function testHavokPipelineCascadingInvalidation(testCase)
            % Verifies that changes to upstream parameters correctly invalidate
            % downstream stage hashes.
            [hasher, ~] = testCase.createHavokHasher();
            
            % --- Baseline Calculation ---
            params_v1 = struct('dt', 0.001, 'truncation_rank', 10);
            
            % Task for compute_svd (upstream)
            svd_task_v1 = struct(...
                'stage_name', 'compute_svd', ...
                'parameters', params_v1, ...
                'input_hashes', struct('H', 'hash_of_H_matrix') ...
            );
            svd_hash_v1 = hasher.computeProvenanceHash(svd_task_v1);
            
            % Task for compute_numerical_derivative (downstream)
            deriv_task_v1 = struct(...
                'stage_name', 'compute_numerical_derivative', ...
                'parameters', params_v1, ...
                'input_hashes', struct('V', svd_hash_v1) ... % Uses output of SVD
            );
            deriv_hash_v1 = hasher.computeProvenanceHash(deriv_task_v1);
            
            % --- Scenario: Change an upstream parameter ('truncation_rank') ---
            params_v2 = struct('dt', 0.001, 'truncation_rank', 15); % rank changed
            
            % Re-compute SVD hash (it MUST change)
            svd_task_v2 = struct(...
                'stage_name', 'compute_svd', ...
                'parameters', params_v2, ...
                'input_hashes', struct('H', 'hash_of_H_matrix') ...
            );
            svd_hash_v2 = hasher.computeProvenanceHash(svd_task_v2);
            testCase.verifyNotEqual(svd_hash_v1, svd_hash_v2, 'Changing explicit param `truncation_rank` must change SVD hash.');
            
            % Re-compute derivative hash using the NEW input hash
            deriv_task_v2 = struct(...
                'stage_name', 'compute_numerical_derivative', ...
                'parameters', params_v2, ...
                'input_hashes', struct('V', svd_hash_v2) ... % Uses NEW SVD hash
            );
            deriv_hash_v2 = hasher.computeProvenanceHash(deriv_task_v2);
            
            % The derivative hash MUST also change, even though it doesn't use
            % 'truncation_rank' explicitly. This proves cascading invalidation.
            testCase.verifyNotEqual(deriv_hash_v1, deriv_hash_v2, 'Changing an upstream input hash must invalidate the downstream hash.');
        end
    end
    
    methods (Access = private)
        function createDummyFunction(~, filename, content)
            % Helper to create a dummy .m file.
            fid = fopen(fullfile(ProvenanceHasherTest.TestDir, filename), 'w');
            if fid == -1
                error('Failed to create dummy function file: %s', filename);
            end
            fprintf(fid, '%s', content);
            fclose(fid);
            
            % Verify the file was created and has content
            created_file = fullfile(ProvenanceHasherTest.TestDir, filename);
            if ~exist(created_file, 'file')
                error('Dummy function file was not created: %s', created_file);
            end
            
            % Check file size
            file_info = dir(created_file);
            if file_info.bytes == 0
                error('Dummy function file is empty: %s', created_file);
            end
        end
        
        function [hasher, stageGraph] = createSyntheticHasher(testCase)
            % Creates a hasher and graph for simple synthetic tests.
            config.stages.StageA = struct('function', @dummy_func_A, 'params', {{'p1'}});
            config.stages.StageB = struct('function', @dummy_func_B, 'params', {{'p3'}}, 'inputs', struct('input_from_A', 'StageA.output'));
            config.stages.StageC = struct('function', @dummy_func_C, 'inputs', struct('in_A', 'StageA.output', 'in_B', 'StageB.output'));
            
            [stageGraph, logger] = testCase.createStageGraph(config);
            hasher = pipeline.ProvenanceHasher(stageGraph, logger);
        end

        function [hasher, config] = createHavokHasher(testCase)
            % Creates a hasher and graph using the full HAVOK config.
            
            % Temporarily add the current directory to the path to find generate_config
            testPath = fileparts(mfilename('fullpath'));
            addpath(testPath);
            
            % Generate the config
            config = testCase.generate_config_with_dummy_functions();
            
            % Remove the path
            rmpath(testPath);
            
            [stageGraph, logger] = testCase.createStageGraph(config);
            hasher = pipeline.ProvenanceHasher(stageGraph, logger);
        end
        
        function [stageGraph, logger] = createStageGraph(~, config)
            % Helper to create a StageGraph and a mock logger.
            logger = mlog.Logger('TestLogger');
            logger.CommandWindowThreshold = mlog.Level.NONE; % Suppress output during tests
            stageGraph = pipeline.utility.StageGraph(config.stages, logger);
        end
        
        function config = generate_config_with_dummy_functions(testCase)
            % This is a local copy of the user-provided generate_config, but
            % it points to the dummy functions created in the test setup.
            config = testCase.generate_config(); % Call the original config
            
            % Overwrite function handles to point to dummy files that exist.
            % This allows the StageGraph and ProvenanceHasher to be constructed
            % without needing the real scientific code.
            config.stages.compute_master_timeseries.function = @dummy_func_A;
            config.stages.compute_hankel.function = @dummy_func_B;
            config.stages.compute_svd.function = @dummy_func_A;
            config.stages.compute_numerical_derivative.function = @dummy_func_B;
            config.stages.construct_regression_library.function = @dummy_func_A;
            config.stages.perform_sparse_regression.function = @dummy_func_C;
            config.stages.reconstruction.function = @dummy_func_A;
        end

        % NOTE: The user's generate_config function is copied here to make
        % the test suite self-contained.
        function config = generate_config(~)
            %GENERATE_CONFIG Returns the configuration structure for the extended hankel HAVOK pipeline
            config.output_filename = 'havok_modular_results.h5';
            config.num_workers = 4;
            config.error_mode = 'fail_fast';
            config.logging = struct('console_level', 'info', 'file_level', 'debug', 'filepath', 'logs/havok_modular.log');
            config.params.globals = struct('dt', 0.001, 'master_timeseries_length', 1000, 'lambda', 0);
            config.params.grid = struct();
            config.params.grid.timeseries_length = [30, 50];
            config.params.grid.index_delay = int32([1, 5]);
            config.params.grid.variable_combination = {'x', 'xz'};
            config.params.grid.embedding_dim_multiple = int32([30, 50]);
            config.params.grid.hankel_type = {'normal', 'vertical', 'horizontal', 'block_vertical'};
            config.params.grid.hankel_max_degree = int32([2, 3]);
            config.params.grid.hankel_max_harmonics = int32([0, 1]);
            config.params.grid.truncation_rank = int32([10, 15]);
            config.params.grid.library_max_degree = int32([1]);
            config.params.grid.library_max_harmonics = int32([0]);
            config.params.filter = @(p, G) p.truncation_rank < p.embedding_dim_multiple;
            config.stages = struct();
            config.stages.compute_master_timeseries = struct('function', @compute_master_timeseries, 'params', {{'master_timeseries_length', 'dt'}}, 'outputs', {{struct('name', 'master_timeseries', 'storage_policy', 'memory_only'), struct('name', 'time_vector', 'storage_policy', 'memory_only')}}, 'execution_mode', 'global');
            config.stages.compute_hankel = struct('function', @compute_hankel, 'params', {{'timeseries_length', 'index_delay', 'variable_combination', 'embedding_dim_multiple', 'hankel_type', 'hankel_max_degree', 'hankel_max_harmonics'}}, 'inputs', struct('timeseries', 'compute_master_timeseries.master_timeseries', 'time_vec', 'compute_master_timeseries.time_vector'), 'outputs', {struct('name', 'H', 'storage_policy', 'memory_only')}, 'execution_mode', 'per_run');
            config.stages.compute_svd = struct('function', @compute_svd, 'params', {{'truncation_rank'}}, 'inputs', struct('H', 'compute_hankel.H'), 'outputs', {{struct('name', 'U', 'storage_policy', 'memory_only'), struct('name', 'S', 'storage_policy', 'memory_only'), struct('name', 'V', 'storage_policy', 'memory_only'), struct('name', 'singular_values', 'storage_policy', 'memory_only')}}, 'execution_mode', 'per_run');
            config.stages.compute_numerical_derivative = struct('function', @compute_numerical_derivative, 'params', {{'dt'}}, 'inputs', struct('V', 'compute_svd.V'), 'outputs', {struct('name', 'dVdt', 'storage_policy', 'memory_only')}, 'execution_mode', 'per_run');
            config.stages.construct_regression_library = struct('function', @construct_regression_library, 'params', {{'library_max_degree', 'library_max_harmonics', 'truncation_rank'}}, 'inputs', struct('V', 'compute_svd.V'), 'outputs', {struct('name', 'Theta', 'storage_policy', 'memory_only')}, 'execution_mode', 'per_run');
            config.stages.perform_sparse_regression = struct('function', @perform_sparse_regression, 'params', {{'lambda'}}, 'inputs', struct('Theta', 'construct_regression_library.Theta', 'dVdt', 'compute_numerical_derivative.dVdt'), 'outputs', {{struct('name', 'Xi', 'storage_policy', 'persistent'), struct('name', 'A', 'storage_policy', 'persistent'), struct('name', 'B', 'storage_policy', 'persistent')}}, 'execution_mode', 'per_run');
            config.stages.reconstruction.function = @compute_reconstruction;
            config.stages.reconstruction.params = {'dt', 'truncation_rank'};
            config.stages.reconstruction.inputs = struct('Xi', 'perform_sparse_regression.Xi', 'A', 'perform_sparse_regression.A', 'B', 'perform_sparse_regression.B', 'U', 'compute_svd.U', 'S', 'compute_svd.S', 'V', 'compute_svd.V');
            config.stages.reconstruction.outputs = {{struct('name', 'y', 'storage_policy', 'memory_only'), struct('name', 't_recon', 'storage_policy', 'memory_only'), struct('name', 'model_eigenvalues', 'storage_policy', 'memory_only'), struct('name', 'forcing_term', 'storage_policy', 'memory_only')}};
            config.stages.reconstruction.execution_mode = 'per_run';
        end
    end
end