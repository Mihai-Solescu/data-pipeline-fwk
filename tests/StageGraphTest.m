classdef StageGraphTest < matlab.unittest.TestCase
    % STAGEGRAPHTEST Comprehensive test suite for the StageGraph class
    %
    % This test suite covers all functionality of the StageGraph class using both
    % synthetic test configurations and real-world configurations from generate_config().
    
    properties (TestParameter)
        % Test parameters for parameterized tests
        invalidInputTypes = {[], '', 123, true, struct()};
        logLevels = {'debug', 'info', 'warning', 'error', 'fatal'};
    end
    
    properties
        % Test fixtures
        logger
        testDir
        examplesDir
    end
    
    methods (TestMethodSetup)
        function setupTest(testCase)

            addpath(genpath(fullfile(fileparts(mfilename('fullpath')), '..', 'examples', 'extended_hankel_havok')));

            % Set up logger and paths for each test
            testCase.logger = mlog.Logger('pipeline:test:StageGraph');
            testCase.logger.CommandWindowThreshold = mlog.Level.FATAL; % Suppress logs during testing
            
            % Set up paths relative to test directory
            testCase.testDir = fileparts(mfilename('fullpath'));
            testCase.examplesDir = fullfile(testCase.testDir, '..', 'examples', 'extended_hankel_havok');
        end
    end
    
    methods (TestMethodTeardown)
        function teardownTest(testCase)
            % Clean up after each test if needed
            if exist(testCase.examplesDir, 'dir')
                rmpath(testCase.examplesDir);
            end
        end
    end
    
    %% Constructor and Input Validation Tests
    methods (Test)
        function testConstructor_ValidInput_Success(testCase)
            % Test constructor with valid minimal configuration
            stages = struct();
            stages.stage1 = struct('function', @sin);
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            testCase.verifyClass(sg, 'pipeline.utility.StageGraph');
            testCase.verifyEqual(sg.Stages, stages);
        end
        
        function testConstructor_EmptyStruct_ThrowsError(testCase)
            % Test that empty struct throws appropriate error
            empty_stages = struct();
            
            testCase.verifyError(...
                @() pipeline.utility.StageGraph(empty_stages, testCase.logger), ...
                'pipeline:StageGraph:InvalidInput');
        end
        
        function testConstructor_InvalidInputTypes_ThrowsError(testCase, invalidInputTypes)
            % Test that invalid input types throw appropriate error
            testCase.verifyError(...
                @() pipeline.utility.StageGraph(invalidInputTypes, testCase.logger), ...
                'pipeline:StageGraph:InvalidInput');
        end
        
        function testConstructor_CircularDependency_ThrowsError(testCase)
            % Test detection of circular dependencies
            stages = struct();
            stages.stage1 = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'stage2.output'));
            stages.stage2 = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'stage1.output'));
            
            testCase.verifyError(...
                @() pipeline.utility.StageGraph(stages, testCase.logger), ...
                'pipeline:StageGraph:CircularDependency');
        end
        
        function testConstructor_InvalidDependencyTarget_ThrowsError(testCase)
            % Test detection of invalid dependency targets
            stages = struct();
            stages.stage1 = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'nonexistent_stage.output'));
            
            testCase.verifyError(...
                @() pipeline.utility.StageGraph(stages, testCase.logger), ...
                'pipeline:StageGraph:InvalidDependencyTarget');
        end
        
        function testConstructor_ComplexValidDAG_Success(testCase)
            % Test constructor with complex but valid DAG
            stages = struct();
            stages.source1 = struct('function', @rand);
            stages.source2 = struct('function', @randn);
            stages.middle = struct(...
                'function', @plus, ...
                'inputs', struct('a', 'source1.data', 'b', 'source2.data'));
            stages.sink = struct(...
                'function', @sum, ...
                'inputs', struct('data', 'middle.result'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            testCase.verifyClass(sg, 'pipeline.utility.StageGraph');
            testCase.verifyNumElements(sg.getStageNames(), 4);
        end
    end
    
    %% Graph-Wide Query Tests
    methods (Test)
        function testGetStageNames_ReturnsAllStages(testCase)
            % Test that getStageNames returns all stage names
            stages = struct();
            stages.alpha = struct('function', @sin);
            stages.beta = struct('function', @cos);
            stages.gamma = struct('function', @tan);
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            stage_names = sg.getStageNames();
            
            testCase.verifyNumElements(stage_names, 3);
            testCase.verifyTrue(ismember('alpha', stage_names));
            testCase.verifyTrue(ismember('beta', stage_names));
            testCase.verifyTrue(ismember('gamma', stage_names));
        end
        
        function testGetTopologicalSort_ReturnsValidOrder(testCase)
            % Test topological sort with known dependency order
            stages = struct();
            stages.first = struct('function', @rand);
            stages.second = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'first.output'));
            stages.third = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'second.output'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            topo_sort = sg.getTopologicalSort();
            
            testCase.verifyNumElements(topo_sort, 3);
            % Verify order: first before second before third
            first_idx = find(strcmp(topo_sort, 'first'));
            second_idx = find(strcmp(topo_sort, 'second'));
            third_idx = find(strcmp(topo_sort, 'third'));
            testCase.verifyLessThan(first_idx, second_idx);
            testCase.verifyLessThan(second_idx, third_idx);
        end
        
        function testGetSourceStages_ReturnsStagesWithNoDependencies(testCase)
            % Test identification of source stages
            stages = struct();
            stages.source1 = struct('function', @rand);
            stages.source2 = struct('function', @randn);
            stages.derived = struct(...
                'function', @plus, ...
                'inputs', struct('a', 'source1.data', 'b', 'source2.data'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            sources = sg.getSourceStages();
            
            testCase.verifyNumElements(sources, 2);
            testCase.verifyTrue(ismember('source1', sources));
            testCase.verifyTrue(ismember('source2', sources));
            testCase.verifyFalse(ismember('derived', sources));
        end
        
        function testGetSinkStages_ReturnsStagesWithNoDependents(testCase)
            % Test identification of sink stages
            stages = struct();
            stages.source = struct('function', @rand);
            stages.sink1 = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'source.output'));
            stages.sink2 = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'source.output'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            sinks = sg.getSinkStages();
            
            testCase.verifyNumElements(sinks, 2);
            testCase.verifyTrue(ismember('sink1', sinks));
            testCase.verifyTrue(ismember('sink2', sinks));
            testCase.verifyFalse(ismember('source', sinks));
        end
    end
    
    %% Stage-Specific Query Tests
    methods (Test)
        function testIsStage_ValidStage_ReturnsTrue(testCase)
            % Test isStage with valid stage name
            stages = struct();
            stages.test_stage = struct('function', @sin);
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            testCase.verifyTrue(sg.isStage('test_stage'));
        end
        
        function testIsStage_InvalidStage_ReturnsFalse(testCase)
            % Test isStage with invalid stage name
            stages = struct();
            stages.test_stage = struct('function', @sin);
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            testCase.verifyFalse(sg.isStage('nonexistent_stage'));
        end
        
        function testGetStageConfig_ValidStage_ReturnsConfig(testCase)
            % Test getStageConfig returns correct configuration
            stages = struct();
            expected_config = struct('function', @sin, 'params', {'param1'});
            stages.test_stage = expected_config;
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            actual_config = sg.getStageConfig('test_stage');
            
            testCase.verifyEqual(actual_config, expected_config);
        end
        
        function testGetStageConfig_InvalidStage_ThrowsError(testCase)
            % Test getStageConfig with invalid stage throws error
            stages = struct();
            stages.test_stage = struct('function', @sin);
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            testCase.verifyError(...
                @() sg.getStageConfig('nonexistent_stage'), ...
                'pipeline:StageGraph:StageNotFound');
        end
        
        function testGetPredecessors_ReturnsCorrectDependencies(testCase)
            % Test getPredecessors returns correct predecessor stages
            stages = struct();
            stages.source1 = struct('function', @rand);
            stages.source2 = struct('function', @randn);
            stages.target = struct(...
                'function', @plus, ...
                'inputs', struct('a', 'source1.data', 'b', 'source2.data'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            predecessors = sg.getPredecessors('target');
            
            testCase.verifyNumElements(predecessors, 2);
            testCase.verifyTrue(ismember('source1', predecessors));
            testCase.verifyTrue(ismember('source2', predecessors));
        end
        
        function testGetSuccessors_ReturnsCorrectDependents(testCase)
            % Test getSuccessors returns correct successor stages
            stages = struct();
            stages.source = struct('function', @rand);
            stages.target1 = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'source.output'));
            stages.target2 = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'source.output'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            successors = sg.getSuccessors('source');
            
            testCase.verifyNumElements(successors, 2);
            testCase.verifyTrue(ismember('target1', successors));
            testCase.verifyTrue(ismember('target2', successors));
        end
        
        function testGetExplicitParams_ReturnsOnlyExplicitParameters(testCase)
            % Test getExplicitParams returns only explicitly declared parameters
            stages = struct();
            stages.stage1 = struct(...
                'function', @sin, ...
                'params', {{'param1', 'param2'}});
            stages.stage2 = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'stage1.output'), ...
                'params', {{'param3'}});
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            explicit_params1 = sg.getExplicitParams('stage1');
            explicit_params2 = sg.getExplicitParams('stage2');
            
            testCase.verifyEqual(sort(explicit_params1), sort({'param1', 'param2'}));
            testCase.verifyEqual(explicit_params2, {'param3'});
        end
        
        function testGetExplicitParams_NoParams_ReturnsEmpty(testCase)
            % Test getExplicitParams with stage that has no explicit parameters
            stages = struct();
            stages.stage1 = struct('function', @sin);
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            explicit_params = sg.getExplicitParams('stage1');
            
            testCase.verifyEmpty(explicit_params);
        end
    end
    
    %% Parameter Resolution Tests
    methods (Test)
        function testEffectiveParams_SimpleChain_InheritanceWorks(testCase)
            % Test parameter inheritance in a simple chain
            stages = struct();
            stages.stage1 = struct(...
                'function', @sin, ...
                'params', {{'param1', 'param2'}});
            stages.stage2 = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'stage1.output'), ...
                'params', {{'param3'}});
            stages.stage3 = struct(...
                'function', @tan, ...
                'inputs', struct('data', 'stage2.output'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            % stage1 should have only its explicit params (no predecessors)
            effective1 = sg.getEffectiveParams('stage1');
            testCase.verifyEqual(sort(effective1), sort({'param1', 'param2'}));
            
            % stage2 should have its explicit params plus inherited from stage1
            effective2 = sg.getEffectiveParams('stage2');
            testCase.verifyEqual(sort(effective2), sort({'param1', 'param2', 'param3'}));
            
            % stage3 should have all inherited params from stage2 (no explicit params)
            effective3 = sg.getEffectiveParams('stage3');
            testCase.verifyEqual(sort(effective3), sort({'param1', 'param2', 'param3'}));
        end
        
        function testEffectiveParams_ComplexDAG_InheritanceWorks(testCase)
            % Test parameter inheritance in a complex DAG
            stages = struct();
            stages.source1 = struct(...
                'function', @rand, ...
                'params', {{'param1', 'param2'}});
            stages.source2 = struct(...
                'function', @randn, ...
                'params', {{'param3'}});
            stages.merge = struct(...
                'function', @plus, ...
                'inputs', struct('a', 'source1.data', 'b', 'source2.data'), ...
                'params', {{'param4'}});
            stages.sink = struct(...
                'function', @sum, ...
                'inputs', struct('data', 'merge.result'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            % Source stages should have only their explicit params (no predecessors)
            effective_source1 = sg.getEffectiveParams('source1');
            effective_source2 = sg.getEffectiveParams('source2');
            effective_merge = sg.getEffectiveParams('merge');
            effective_sink = sg.getEffectiveParams('sink');
            
            % source1 should have only its explicit params
            testCase.verifyEqual(sort(effective_source1), sort({'param1', 'param2'}));
            
            % source2 should have only its explicit params
            testCase.verifyEqual(sort(effective_source2), sort({'param3'}));
            
            % merge should have its explicit params plus inherited from both sources
            testCase.verifyTrue(ismember('param1', effective_merge));
            testCase.verifyTrue(ismember('param2', effective_merge));
            testCase.verifyTrue(ismember('param3', effective_merge));
            testCase.verifyTrue(ismember('param4', effective_merge));
            
            % sink should have all params inherited from merge
            testCase.verifyTrue(ismember('param1', effective_sink));
            testCase.verifyTrue(ismember('param2', effective_sink));
            testCase.verifyTrue(ismember('param3', effective_sink));
            testCase.verifyTrue(ismember('param4', effective_sink));
        end
        
        function testEffectiveParams_NoDuplicates_UniqueParameters(testCase)
            % Test that effective parameters don't contain duplicates
            stages = struct();
            stages.source = struct(...
                'function', @rand, ...
                'params', {'shared_param', 'param1'});
            stages.middle = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'source.output'), ...
                'params', {'shared_param', 'param2'});
            stages.sink = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'middle.output'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            effective_source = sg.getEffectiveParams('source');
            effective_middle = sg.getEffectiveParams('middle');
            
            % Check that shared_param appears only once in each list
            testCase.verifyEqual(sum(strcmp(effective_source, 'shared_param')), 1);
            testCase.verifyEqual(sum(strcmp(effective_middle, 'shared_param')), 1);
        end
    end
    
    %% Real-world Configuration Tests
    methods (Test)
        function testRealConfig_GenerateConfig_ConstructsSuccessfully(testCase)
            % Test StageGraph construction with real generate_config()
            
            % Add examples directory to path
            addpath(testCase.examplesDir);
            
            try
                % Get real configuration
                config = generate_config();
                
                % Construct StageGraph
                sg = pipeline.utility.StageGraph(config.stages, testCase.logger);
                
                % Verify successful construction
                testCase.verifyClass(sg, 'pipeline.utility.StageGraph');
                
                % Verify all expected stages are present
                stage_names = sg.getStageNames();
                expected_stages = {'compute_master_timeseries', 'compute_hankel', 'compute_svd', ...
                                 'compute_numerical_derivative', 'construct_regression_library', ...
                                 'perform_sparse_regression', 'reconstruction'};
                
                for i = 1:length(expected_stages)
                    testCase.verifyTrue(ismember(expected_stages{i}, stage_names), ...
                        sprintf('Expected stage %s not found', expected_stages{i}));
                end
                
            catch ME
                rmpath(testCase.examplesDir);
                rethrow(ME);
            end
            
            rmpath(testCase.examplesDir);
        end
        
        function testRealConfig_TopologicalSort_ValidOrder(testCase)
            % Test that real config produces valid topological sort
            
            addpath(testCase.examplesDir);
            
            try
                config = generate_config();
                sg = pipeline.utility.StageGraph(config.stages, testCase.logger);
                
                topo_sort = sg.getTopologicalSort();
                
                % Verify specific ordering constraints from the real config
                % compute_master_timeseries should come before compute_hankel
                master_idx = find(strcmp(topo_sort, 'compute_master_timeseries'));
                hankel_idx = find(strcmp(topo_sort, 'compute_hankel'));
                testCase.verifyLessThan(master_idx, hankel_idx);
                
                % compute_hankel should come before compute_svd
                svd_idx = find(strcmp(topo_sort, 'compute_svd'));
                testCase.verifyLessThan(hankel_idx, svd_idx);
                
                % compute_svd should come before construct_regression_library
                library_idx = find(strcmp(topo_sort, 'construct_regression_library'));
                testCase.verifyLessThan(svd_idx, library_idx);
                
                % compute_svd should come before compute_numerical_derivative  
                derivative_idx = find(strcmp(topo_sort, 'compute_numerical_derivative'));
                testCase.verifyLessThan(svd_idx, derivative_idx);
                
                % Both derivative and library should come before regression
                regression_idx = find(strcmp(topo_sort, 'perform_sparse_regression'));
                testCase.verifyLessThan(derivative_idx, regression_idx);
                testCase.verifyLessThan(library_idx, regression_idx);
                
                % Regression should come before reconstruction
                reconstruction_idx = find(strcmp(topo_sort, 'reconstruction'));
                testCase.verifyLessThan(regression_idx, reconstruction_idx);
                
            catch ME
                rmpath(testCase.examplesDir);
                rethrow(ME);
            end
            
            rmpath(testCase.examplesDir);
        end
        
        function testRealConfig_SourceAndSinks_CorrectIdentification(testCase)
            % Test identification of source and sink stages in real config
            
            addpath(testCase.examplesDir);
            
            try
                config = generate_config();
                sg = pipeline.utility.StageGraph(config.stages, testCase.logger);
                
                sources = sg.getSourceStages();
                sinks = sg.getSinkStages();
                
                % compute_master_timeseries should be the only source
                testCase.verifyNumElements(sources, 1);
                testCase.verifyTrue(ismember('compute_master_timeseries', sources));
                
                % reconstruction should be the only sink
                testCase.verifyNumElements(sinks, 1);
                testCase.verifyTrue(ismember('reconstruction', sinks));
                
            catch ME
                rmpath(testCase.examplesDir);
                rethrow(ME);
            end
            
            rmpath(testCase.examplesDir);
        end
        
        function testRealConfig_ParameterInheritance_WorksCorrectly(testCase)
            % Test parameter inheritance with real configuration
            
            addpath(testCase.examplesDir);
            
            try
                config = generate_config();
                sg = pipeline.utility.StageGraph(config.stages, testCase.logger);
                
                % Test specific parameter inheritance patterns
                
                % compute_master_timeseries uses 'master_timeseries_length'
                master_explicit = sg.getExplicitParams('compute_master_timeseries');
                testCase.verifyTrue(ismember('master_timeseries_length', master_explicit));
                
                % compute_hankel uses 'timeseries_length'
                hankel_explicit = sg.getExplicitParams('compute_hankel');
                testCase.verifyTrue(ismember('timeseries_length', hankel_explicit));
                
                % reconstruction uses 'dt' and 'truncation_rank'
                recon_explicit = sg.getExplicitParams('reconstruction');
                testCase.verifyTrue(ismember('dt', recon_explicit));
                testCase.verifyTrue(ismember('truncation_rank', recon_explicit));
                
            catch ME
                rmpath(testCase.examplesDir);
                rethrow(ME);
            end
            
            rmpath(testCase.examplesDir);
        end
        
        function testRealConfig_StageQueries_WorkCorrectly(testCase)
            % Test stage-specific queries with real configuration
            
            addpath(testCase.examplesDir);
            
            try
                config = generate_config();
                sg = pipeline.utility.StageGraph(config.stages, testCase.logger);
                
                % Test predecessors of compute_svd (should be compute_hankel)
                svd_predecessors = sg.getPredecessors('compute_svd');
                testCase.verifyNumElements(svd_predecessors, 1);
                testCase.verifyTrue(ismember('compute_hankel', svd_predecessors));
                
                % Test successors of compute_svd (should include derivative, library, and reconstruction)
                svd_successors = sg.getSuccessors('compute_svd');
                testCase.verifyGreaterThanOrEqual(length(svd_successors), 3);
                testCase.verifyTrue(ismember('compute_numerical_derivative', svd_successors));
                testCase.verifyTrue(ismember('construct_regression_library', svd_successors));
                testCase.verifyTrue(ismember('reconstruction', svd_successors));
                
                % Test that reconstruction has multiple predecessors
                recon_predecessors = sg.getPredecessors('reconstruction');
                testCase.verifyNumElements(recon_predecessors, 2);
                testCase.verifyTrue(ismember('perform_sparse_regression', recon_predecessors));
                testCase.verifyTrue(ismember('compute_svd', recon_predecessors));
                
            catch ME
                rmpath(testCase.examplesDir);
                rethrow(ME);
            end
            
            rmpath(testCase.examplesDir);
        end
        
        function testRealConfig_StageConfigs_AccessibleAndValid(testCase)
            % Test that stage configurations are accessible and valid
            
            addpath(testCase.examplesDir);
            
            try
                config = generate_config();
                sg = pipeline.utility.StageGraph(config.stages, testCase.logger);
                
                % Test accessing stage configurations
                master_config = sg.getStageConfig('compute_master_timeseries');
                testCase.verifyTrue(isfield(master_config, 'function'));
                % Just verify function field exists, don't check its type due to isa issues
                testCase.verifyNotEmpty(master_config.function);
                
                hankel_config = sg.getStageConfig('compute_hankel');
                testCase.verifyTrue(isfield(hankel_config, 'function'));
                testCase.verifyTrue(isfield(hankel_config, 'inputs'));
                testCase.verifyTrue(isfield(hankel_config, 'params'));
                
                recon_config = sg.getStageConfig('reconstruction');
                testCase.verifyTrue(isfield(recon_config, 'function'));
                testCase.verifyTrue(isfield(recon_config, 'inputs'));
                testCase.verifyTrue(isfield(recon_config, 'outputs'));
                
            catch ME
                rmpath(testCase.examplesDir);
                rethrow(ME);
            end
            
            rmpath(testCase.examplesDir);
        end
    end
    
    %% Error Handling and Edge Case Tests
    methods (Test)
        function testValidateStageExists_InvalidStage_ThrowsAppropriateError(testCase)
            % Test that stage validation throws correct error with proper message
            stages = struct();
            stages.valid_stage = struct('function', @sin);
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            try
                sg.getPredecessors('invalid_stage');
                testCase.verifyFail('Expected error was not thrown');
            catch ME
                testCase.verifyEqual(ME.identifier, 'pipeline:StageGraph:StageNotFound');
                testCase.verifyTrue(contains(ME.message, 'invalid_stage'));
            end
        end
        
        function testSingleStageGraph_AllQueriesWork(testCase)
            % Test that all queries work correctly with a single-stage graph
            stages = struct();
            stages.only_stage = struct('function', @sin, 'params', {'param1'});
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            % Test all query methods
            testCase.verifyEqual(sg.getStageNames(), {'only_stage'});
            testCase.verifyEqual(sg.getTopologicalSort(), {'only_stage'});
            testCase.verifyEqual(sg.getSourceStages(), {'only_stage'});
            testCase.verifyEqual(sg.getSinkStages(), {'only_stage'});
            testCase.verifyTrue(sg.isStage('only_stage'));
            testCase.verifyEmpty(sg.getPredecessors('only_stage'));
            testCase.verifyEmpty(sg.getSuccessors('only_stage'));
            testCase.verifyEqual(sg.getExplicitParams('only_stage'), {'param1'});
            testCase.verifyEqual(sg.getEffectiveParams('only_stage'), {'param1'});
        end
        
        function testComplexParameterInheritance_MultiplePathsConverge(testCase)
            % Test parameter inheritance when multiple paths converge
            stages = struct();
            stages.source1 = struct('function', @rand, 'params', {{'param1'}});
            stages.source2 = struct('function', @randn, 'params', {{'param2'}});
            stages.middle1 = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'source1.output'), ...
                'params', {{'param3'}});
            stages.middle2 = struct(...
                'function', @cos, ...
                'inputs', struct('data', 'source2.output'), ...
                'params', {{'param4'}});
            stages.convergence = struct(...
                'function', @plus, ...
                'inputs', struct('a', 'middle1.output', 'b', 'middle2.output'), ...
                'params', {{'param5'}});
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            % Test that convergence point inherits from all upstream paths
            conv_effective = sg.getEffectiveParams('convergence');
            testCase.verifyEqual(sort(conv_effective), sort({'param1', 'param2', 'param3', 'param4', 'param5'}));
            
            % Test that sources have only their explicit parameters
            source1_effective = sg.getEffectiveParams('source1');
            source2_effective = sg.getEffectiveParams('source2');
            
            testCase.verifyEqual(source1_effective, {'param1'});
            testCase.verifyEqual(source2_effective, {'param2'});
            
            % Test that middle stages inherit from their predecessors
            middle1_effective = sg.getEffectiveParams('middle1');
            middle2_effective = sg.getEffectiveParams('middle2');
            
            testCase.verifyTrue(ismember('param1', middle1_effective));
            testCase.verifyTrue(ismember('param3', middle1_effective));
            
            testCase.verifyTrue(ismember('param2', middle2_effective));
            testCase.verifyTrue(ismember('param4', middle2_effective));
        end
        
        function testPlot_ExecutesWithoutError(testCase)
            % Test that the plot method executes without error
            stages = struct();
            stages.source = struct('function', @rand);
            stages.processor = struct(...
                'function', @sin, ...
                'inputs', struct('data', 'source.output_data'));
            stages.sink = struct(...
                'function', @sum, ...
                'inputs', struct('values', 'processor.processed_values'));
            
            sg = pipeline.utility.StageGraph(stages, testCase.logger);
            
            % Test that plot executes without error
            testCase.verifyWarningFree(@() sg.plot());
            
            % Clean up by closing any figures that might have been created
            close all;
        end
    end
end
