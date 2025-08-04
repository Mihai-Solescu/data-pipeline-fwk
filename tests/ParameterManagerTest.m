classdef ParameterManagerTest < matlab.unittest.TestCase
    % ParameterManagerTest - Comprehensive test suite for ParameterManager
    %
    % This test class validates all functionality of the ParameterManager service
    % according to the specifications in ADD.md. It covers:
    % - Grid generation and Cartesian products
    % - Global parameter merging
    % - Filter application
    % - Task projection
    % - Edge cases and error conditions
    
    properties (TestParameter)
        % Test parameters for parameterized tests
    end
    
    properties
        test_logger  % Logger instance for tests
    end
    
    methods (TestMethodSetup)
        function setupMethod(testCase)
            % Set up test environment for each test
            testCase.test_logger = mlog.Logger('test:ParameterManagerTest');
            % Configure logger for testing (reduce output during tests)
            testCase.test_logger.CommandWindowThreshold = mlog.Level.WARNING;
        end
    end
    
    methods (Test)
        function testGridGeneration(testCase)
            % Test basic grid generation with Cartesian product
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct();
            config_params.grid.param1 = [1, 2];
            config_params.grid.param2 = [10, 20, 30];
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            testCase.verifyEqual(length(runs), 6, 'Should generate 2x3=6 combinations');
            
            % Verify all combinations are present
            expected_combinations = {
                struct('param1', 1, 'param2', 10),
                struct('param1', 1, 'param2', 20),
                struct('param1', 1, 'param2', 30),
                struct('param1', 2, 'param2', 10),
                struct('param1', 2, 'param2', 20),
                struct('param1', 2, 'param2', 30)
            };
            
            for i = 1:length(expected_combinations)
                found = false;
                for j = 1:length(runs)
                    if isequal(runs{j}, expected_combinations{i})
                        found = true;
                        break;
                    end
                end
                testCase.verifyTrue(found, sprintf('Expected combination %d not found', i));
            end
        end
        
        function testGlobalParameterMerging(testCase)
            % Test that global parameters are correctly added to every run
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('dt', 0.001, 'solver', 'ode45');
            config_params.grid = struct('rank', [5, 10]);
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            testCase.verifyEqual(length(runs), 2, 'Should have 2 runs for 2 grid values');
            
            for i = 1:length(runs)
                run = runs{i};
                testCase.verifyEqual(run.dt, 0.001, 'Global dt should be present');
                testCase.verifyEqual(run.solver, 'ode45', 'Global solver should be present');
                testCase.verifyTrue(ismember(run.rank, [5, 10]), 'Grid rank should be present');
            end
        end
        
        function testFilterApplication(testCase)
            % Test that filter function is correctly applied
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct('value', [1, 2, 3, 4, 5]);
            % Filter to keep only even values
            config_params.filter = @(p, G) mod(p.value, 2) == 0;
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            testCase.verifyEqual(length(runs), 2, 'Should keep only 2 even values');
            
            values = cellfun(@(r) r.value, runs);
            testCase.verifyEqual(sort(values), [2, 4], 'Should keep values 2 and 4');
        end
        
        function testTaskProjection(testCase)
            % Test the critical getProjectedTasks method
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('dt', 0.001);
            config_params.grid = struct();
            config_params.grid.rank = [5, 10, 15];
            config_params.grid.method = {'svd', 'eig'};
            
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            
            % Act - Project onto subset of parameters
            effective_params = {'rank', 'dt'};
            projected_tasks = pm.getProjectedTasks(effective_params);
            
            % Assert
            % Should have 3 unique tasks (one for each rank value)
            % since dt is constant across all runs
            testCase.verifyEqual(length(projected_tasks), 3, ...
                'Should have 3 unique projections for 3 rank values');
            
            % Verify each projected task has correct structure
            for i = 1:length(projected_tasks)
                task = projected_tasks{i};
                testCase.verifyTrue(isfield(task, 'rank'), 'Task should have rank field');
                testCase.verifyTrue(isfield(task, 'dt'), 'Task should have dt field');
                testCase.verifyFalse(isfield(task, 'method'), 'Task should not have method field');
                testCase.verifyEqual(task.dt, 0.001, 'dt should be correct');
                testCase.verifyTrue(ismember(task.rank, [5, 10, 15]), 'rank should be valid');
            end
        end
        
        function testProjectionWithNoEffectiveParams(testCase)
            % Test projection with empty effective parameters
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('dt', 0.001);
            config_params.grid = struct('rank', [5, 10]);
            
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            
            % Act
            projected_tasks = pm.getProjectedTasks({});
            
            % Assert
            testCase.verifyEqual(length(projected_tasks), 1, ...
                'Should return single task for empty parameter set');
            testCase.verifyTrue(isstruct(projected_tasks{1}), 'Task should be a struct');
            testCase.verifyEqual(length(fieldnames(projected_tasks{1})), 0, ...
                'Task should be empty struct');
        end
        
        function testEdgeCaseNoGridParams(testCase)
            % Test behavior when grid is empty (only globals)
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('dt', 0.001, 'method', 'euler');
            config_params.grid = struct(); % Empty grid
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            testCase.verifyEqual(length(runs), 1, 'Should have exactly one run');
            
            run = runs{1};
            testCase.verifyEqual(run.dt, 0.001, 'Should have global dt');
            testCase.verifyEqual(run.method, 'euler', 'Should have global method');
        end
        
        function testEdgeCaseFilterRemovesAll(testCase)
            % Test warning when filter removes all runs
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct('value', [1, 2, 3]);
            % Filter that rejects everything
            config_params.filter = @(p, G) false;
            
            % Act & Assert
            % Should not throw error but should log warning
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            testCase.verifyEqual(length(runs), 0, 'Should have no approved runs');
        end
        
        function testErrorOnInvalidFilterHandle(testCase)
            % Test error when filter is not a function handle
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct('value', [1, 2]);
            config_params.filter = 'not_a_function'; % Invalid
            
            % Act & Assert
            testCase.verifyError(@() pipeline.ParameterManager(config_params, testCase.test_logger), ...
                'pipeline:ParameterManager:InvalidFilterFunction');
        end
        
        function testParameterNameCollisionError(testCase)
            % Test error when parameter names collide between globals and grid
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('dt', 0.001);
            config_params.grid = struct('dt', [0.001, 0.002]); % Collision!
            
            % Act & Assert
            testCase.verifyError(@() pipeline.ParameterManager(config_params, testCase.test_logger), ...
                'pipeline:ParameterManager:ParameterNameCollision');
        end
        
        function testComplexFilterWithGlobalContext(testCase)
            % Test filter function that uses global context (G parameter)
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct();
            config_params.grid.rank = [5, 10, 15, 20];
            config_params.grid.tolerance = [1e-6, 1e-8];
            
            % Filter: keep only runs where rank is at least half of max rank
            config_params.filter = @(p, G) p.rank >= max(G.rank) / 2;
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            % Should keep rank >= 10 (half of max 20)
            testCase.verifyEqual(length(runs), 6, 'Should keep 3 ranks × 2 tolerances = 6 runs');
            
            for i = 1:length(runs)
                testCase.verifyGreaterThanOrEqual(runs{i}.rank, 10, ...
                    'All kept ranks should be >= 10');
            end
        end
        
        function testProjectionWithMixedDataTypes(testCase)
            % Test projection with different parameter data types
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('use_gpu', true);
            config_params.grid = struct();
            config_params.grid.rank = [5, 10];
            config_params.grid.method = {'svd', 'eig'};
            config_params.grid.tolerance = [1e-6, 1e-8];
            
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            
            % Act - Project onto mixed types
            effective_params = {'use_gpu', 'method'};
            projected_tasks = pm.getProjectedTasks(effective_params);
            
            % Assert
            % Should have 2 unique tasks (one for each method)
            % since use_gpu is constant
            testCase.verifyEqual(length(projected_tasks), 2, ...
                'Should have 2 unique projections for 2 method values');
            
            methods_found = {};
            for i = 1:length(projected_tasks)
                task = projected_tasks{i};
                testCase.verifyEqual(task.use_gpu, true, 'use_gpu should be correct');
                testCase.verifyTrue(ismember(task.method, {'svd', 'eig'}), ...
                    'method should be valid');
                methods_found{end+1} = task.method; %#ok<AGROW>
            end
            
            testCase.verifyEqual(length(unique(methods_found)), 2, ...
                'Should have found both methods');
        end
        
        function testLargeParameterSpace(testCase)
            % Test performance with larger parameter space
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('dt', 0.001);
            config_params.grid = struct();
            config_params.grid.rank = 1:20;        % 20 values
            config_params.grid.method = {'svd', 'eig', 'qr'}; % 3 values
            config_params.grid.tolerance = [1e-4, 1e-6, 1e-8]; % 3 values
            % Total: 20 × 3 × 3 = 180 combinations
            
            % Act
            tic;
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            construction_time = toc;
            
            tic;
            projected_tasks = pm.getProjectedTasks({'rank', 'dt'});
            projection_time = toc;
            
            % Assert
            testCase.verifyEqual(pm.getNumApprovedRuns(), 180, ...
                'Should have 180 total runs');
            testCase.verifyEqual(length(projected_tasks), 20, ...
                'Should have 20 unique projections for rank');
            
            % Performance assertions (should complete quickly)
            testCase.verifyLessThan(construction_time, 1.0, ...
                'Construction should complete in under 1 second');
            testCase.verifyLessThan(projection_time, 0.1, ...
                'Projection should complete in under 0.1 seconds');
        end
        
        function testErrorOnMissingParameterInProjection(testCase)
            % Test error when projection references non-existent parameter
            
            % Arrange
            config_params = struct();
            config_params.globals = struct('dt', 0.001);
            config_params.grid = struct('rank', [5, 10]);
            
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            
            % Act & Assert
            testCase.verifyError(@() pm.getProjectedTasks({'nonexistent_param'}), ...
                'pipeline:ParameterManager:MissingParameter');
        end
        
        function testFilterFunctionErrorHandling(testCase)
            % Test proper error handling when filter function throws
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct('value', [1, 2, 3]);
            % Filter that throws an error - note: using a more specific error
            config_params.filter = @(p, G) p.nonexistent_field > 0;
            
            % Act & Assert
            testCase.verifyError(@() pipeline.ParameterManager(config_params, testCase.test_logger), ...
                'pipeline:ParameterManager:FilterFunctionError');
        end
        
        function testFilterFunctionInvalidReturnType(testCase)
            % Test error when filter function returns invalid type
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct('value', [1, 2]);
            % Filter that returns non-logical
            config_params.filter = @(p, G) 'not_logical';
            
            % Act & Assert
            testCase.verifyError(@() pipeline.ParameterManager(config_params, testCase.test_logger), ...
                'pipeline:ParameterManager:FilterFunctionError');
        end
        
        function testStringParameterHandling(testCase)
            % Test handling of string/char parameters in grid
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct();
            config_params.grid.method = {'euler', 'rk4', 'ode45'};
            config_params.grid.precision = 'double'; % Single string
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            testCase.verifyEqual(length(runs), 3, 'Should have 3 runs for 3 methods');
            
            for i = 1:length(runs)
                run = runs{i};
                testCase.verifyTrue(ismember(run.method, {'euler', 'rk4', 'ode45'}), ...
                    'Method should be valid');
                testCase.verifyEqual(run.precision, 'double', ...
                    'Precision should be correct');
            end
        end
        
        function testComplexFilterWithoutGlobals(testCase)
            % Test complex filter that only depends on grid parameters
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.grid = struct();
            config_params.grid.rank = [5, 10, 15, 20, 25];
            config_params.grid.tolerance = [1e-4, 1e-6, 1e-8];
            config_params.grid.method = {'svd', 'eig'};
            
            % Filter: keep only runs where rank is odd AND tolerance >= 1e-6
            config_params.filter = @(p, G) mod(p.rank, 2) == 1 && p.tolerance >= 1e-6;
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            % Should keep ranks [5, 15, 25] (odd) with tolerances [1e-4, 1e-6] (>= 1e-6)
            % That's 3 ranks × 2 tolerances × 2 methods = 12 runs
            testCase.verifyEqual(length(runs), 12, 'Should keep 12 runs');
            
            for i = 1:length(runs)
                run = runs{i};
                testCase.verifyEqual(mod(run.rank, 2), 1, 'All ranks should be odd');
                testCase.verifyGreaterThanOrEqual(run.tolerance, 1e-6, 'All tolerances should be >= 1e-6');
            end
        end
        
        function testComplexFilterWithGlobalsInP(testCase)
            % Test filter that uses global parameters passed in p
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.globals.dt = 0.001;
            config_params.globals.max_iterations = 1000;
            config_params.globals.use_adaptive = true;
            config_params.grid = struct();
            config_params.grid.rank = [5, 10, 15, 20];
            config_params.grid.solver = {'euler', 'rk4', 'ode45'};
            
            % Filter: keep runs where rank * dt < 0.02 AND solver is not 'euler' when adaptive is true
            config_params.filter = @(p, G) (p.rank * p.dt < 0.02) && ...
                (~p.use_adaptive || ~strcmp(p.solver, 'euler'));
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            % rank * dt < 0.02 means rank < 20, so ranks [5, 10, 15] qualify
            % use_adaptive is true, so exclude 'euler', keeping ['rk4', 'ode45']
            % Expected: 3 ranks × 2 solvers = 6 runs
            testCase.verifyEqual(length(runs), 6, 'Should keep 6 runs');
            
            for i = 1:length(runs)
                run = runs{i};
                testCase.verifyLessThan(run.rank * run.dt, 0.02, 'rank * dt should be < 0.02');
                testCase.verifyFalse(strcmp(run.solver, 'euler'), 'Solver should not be euler when adaptive');
                testCase.verifyEqual(run.use_adaptive, true, 'Global parameter should be present');
                testCase.verifyEqual(run.dt, 0.001, 'Global parameter should be present');
                testCase.verifyEqual(run.max_iterations, 1000, 'Global parameter should be present');
            end
        end
        
        function testFilterWithStringComparisons(testCase)
            % Test filter with string/char parameter comparisons
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.globals.mode = 'production';
            config_params.grid = struct();
            config_params.grid.algorithm = {'fast', 'accurate', 'balanced'};
            config_params.grid.precision = {'single', 'double'};
            config_params.grid.debug_level = [0, 1, 2];
            
            % Filter: in production mode, only allow 'accurate' or 'balanced' algorithms with double precision
            % and debug_level <= 1
            config_params.filter = @(p, G) strcmp(p.mode, 'production') && ...
                (strcmp(p.algorithm, 'accurate') || strcmp(p.algorithm, 'balanced')) && ...
                strcmp(p.precision, 'double') && p.debug_level <= 1;
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            % Should keep algorithms ['accurate', 'balanced'] with precision 'double' and debug_level [0, 1]
            % Expected: 2 algorithms × 1 precision × 2 debug_levels = 4 runs
            testCase.verifyEqual(length(runs), 4, 'Should keep 4 runs');
            
            for i = 1:length(runs)
                run = runs{i};
                testCase.verifyEqual(run.mode, 'production', 'Mode should be production');
                testCase.verifyTrue(strcmp(run.algorithm, 'accurate') || strcmp(run.algorithm, 'balanced'), ...
                    'Algorithm should be accurate or balanced');
                testCase.verifyEqual(run.precision, 'double', 'Precision should be double');
                testCase.verifyLessThanOrEqual(run.debug_level, 1, 'Debug level should be <= 1');
            end
        end
        
        function testFilterWithLogicalGlobals(testCase)
            % Test filter with logical global parameters
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.globals.enable_optimization = true;
            config_params.globals.use_gpu = false;
            config_params.globals.save_intermediate = true;
            config_params.grid = struct();
            config_params.grid.batch_size = [16, 32, 64, 128];
            config_params.grid.learning_rate = [0.001, 0.01, 0.1];
            
            % Filter: when optimization is enabled and GPU is disabled, use smaller batch sizes and learning rates
            config_params.filter = @(p, G) p.enable_optimization && ~p.use_gpu && ...
                p.batch_size <= 64 && p.learning_rate <= 0.01;
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            % Should keep batch_sizes [16, 32, 64] and learning_rates [0.001, 0.01]
            % Expected: 3 batch_sizes × 2 learning_rates = 6 runs
            testCase.verifyEqual(length(runs), 6, 'Should keep 6 runs');
            
            for i = 1:length(runs)
                run = runs{i};
                testCase.verifyEqual(run.enable_optimization, true, 'Optimization should be enabled');
                testCase.verifyEqual(run.use_gpu, false, 'GPU should be disabled');
                testCase.verifyEqual(run.save_intermediate, true, 'Save intermediate should be true');
                testCase.verifyLessThanOrEqual(run.batch_size, 64, 'Batch size should be <= 64');
                testCase.verifyLessThanOrEqual(run.learning_rate, 0.01, 'Learning rate should be <= 0.01');
            end
        end
        
        function testFilterWithMixedGlobalAndGridLogic(testCase)
            % Test complex filter mixing global and grid parameters with conditional logic
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.globals.memory_limit_gb = 8;
            config_params.globals.cpu_cores = 4;
            config_params.globals.is_cluster = false;
            config_params.grid = struct();
            config_params.grid.problem_size = [100, 500, 1000, 5000];
            config_params.grid.parallel_workers = [1, 2, 4, 8];
            config_params.grid.memory_per_worker = [1, 2, 4]; % GB
            
            % Filter: ensure total memory usage doesn't exceed limit and workers don't exceed cores
            % unless on cluster. Also, larger problems need more workers.
            config_params.filter = @(p, G) ...
                (p.parallel_workers * p.memory_per_worker <= p.memory_limit_gb) && ...
                (p.is_cluster || p.parallel_workers <= p.cpu_cores) && ...
                (p.problem_size < 1000 || p.parallel_workers >= 2);
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert - verify all constraints are satisfied
            testCase.verifyGreaterThan(length(runs), 0, 'Should have some valid runs');
            
            for i = 1:length(runs)
                run = runs{i};
                
                % Check memory constraint
                testCase.verifyLessThanOrEqual(run.parallel_workers * run.memory_per_worker, ...
                    run.memory_limit_gb, 'Total memory should not exceed limit');
                
                % Check worker constraint (only applies when not on cluster)
                if ~run.is_cluster
                    testCase.verifyLessThanOrEqual(run.parallel_workers, run.cpu_cores, ...
                        'Workers should not exceed cores when not on cluster');
                end
                
                % Check problem size constraint
                if run.problem_size >= 1000
                    testCase.verifyGreaterThanOrEqual(run.parallel_workers, 2, ...
                        'Large problems should use at least 2 workers');
                end
                
                % Verify global parameters are present
                testCase.verifyEqual(run.memory_limit_gb, 8, 'Global parameter should be present');
                testCase.verifyEqual(run.cpu_cores, 4, 'Global parameter should be present');
                testCase.verifyEqual(run.is_cluster, false, 'Global parameter should be present');
            end
        end
        
        function testFilterWithGlobalMetadataContext(testCase)
            % Test filter that uses the G parameter (global metadata) for relative comparisons
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.globals.base_tolerance = 1e-6;
            config_params.grid = struct();
            config_params.grid.rank = [5, 10, 15, 20, 25, 30];
            config_params.grid.iterations = [100, 500, 1000, 2000];
            config_params.grid.tolerance_multiplier = [0.1, 1.0, 10.0];
            
            % Filter: keep runs where rank is in the middle range and iterations scale with rank
            % Use G to find min/max values for relative comparisons
            config_params.filter = @(p, G) ...
                (p.rank >= min(G.rank) + (max(G.rank) - min(G.rank)) * 0.2) && ...
                (p.rank <= min(G.rank) + (max(G.rank) - min(G.rank)) * 0.8) && ...
                (p.iterations >= p.rank * 10) && ...
                (p.tolerance_multiplier * p.base_tolerance <= 1e-5);
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            testCase.verifyGreaterThan(length(runs), 0, 'Should have some valid runs');
            
            % Calculate expected rank range: 20% to 80% of [5, 30] = [10, 25]
            min_rank = 5 + (30 - 5) * 0.2; % 10
            max_rank = 5 + (30 - 5) * 0.8; % 25
            
            for i = 1:length(runs)
                run = runs{i};
                
                % Check rank is in middle range
                testCase.verifyGreaterThanOrEqual(run.rank, min_rank, 'Rank should be >= 10');
                testCase.verifyLessThanOrEqual(run.rank, max_rank, 'Rank should be <= 25');
                
                % Check iterations scale with rank
                testCase.verifyGreaterThanOrEqual(run.iterations, run.rank * 10, ...
                    'Iterations should scale with rank');
                
                % Check tolerance constraint
                testCase.verifyLessThanOrEqual(run.tolerance_multiplier * run.base_tolerance, 1e-5, ...
                    'Effective tolerance should be <= 1e-5');
                
                % Verify global parameters are accessible in p
                testCase.verifyEqual(run.base_tolerance, 1e-6, 'Global parameter should be in p');
            end
        end
        
        function testFilterWithEmptyResult(testCase)
            % Test filter that intentionally results in empty set
            
            % Arrange
            config_params = struct();
            config_params.globals = struct();
            config_params.globals.version = 2.0;
            config_params.grid = struct();
            config_params.grid.feature_level = [1, 2, 3];
            config_params.grid.compatibility = [1.0, 1.5, 2.0, 2.5];
            
            % Filter: impossible condition - feature level 4 doesn't exist
            config_params.filter = @(p, G) p.feature_level == 4 && p.compatibility <= p.version;
            
            % Act
            pm = pipeline.ParameterManager(config_params, testCase.test_logger);
            runs = pm.getApprovedRuns();
            
            % Assert
            testCase.verifyEqual(length(runs), 0, 'Should have no runs with impossible filter');
        end
    end
    
    methods (Access = private)
        function verifyStructsEqual(testCase, actual, expected, message)
            % Helper method to verify two structs are equal
            
            if nargin < 4
                message = 'Structs should be equal';
            end
            
            testCase.verifyEqual(fieldnames(actual), fieldnames(expected), ...
                [message, ' - field names should match']);
            
            field_names = fieldnames(expected);
            for i = 1:length(field_names)
                field_name = field_names{i};
                testCase.verifyEqual(actual.(field_name), expected.(field_name), ...
                    sprintf('%s - field %s should match', message, field_name));
            end
        end
    end
end
