classdef ConfigValidatorTest < matlab.unittest.TestCase
    % ConfigValidatorTest - Unit tests for the ConfigValidator class
    % Tests all validation functionality except stage graph validation
    %
    % TODO: Add tests for stage graph validation methods (validateGraphIntegrity, 
    % validateDependencyTargets) once they are integrated into the main validation flow.
    
    properties (TestParameter)
        % Valid log levels for testing
        validLogLevels = {'debug', 'info', 'warning', 'error', 'fatal', 'none', ...
                         'DEBUG', 'INFO', 'WARNING', 'ERROR', 'FATAL', 'NONE', ...
                         'Debug', 'Info', 'Warning', 'Error', 'Fatal', 'None'}
        
        % Invalid log levels for testing
        invalidLogLevels = {'trace', 'verbose', 'critical', '', 'invalid', ...
                           123, true, [], {'debug'}}
                           % Note: struct() removed as it causes conversion errors
    end
    
    properties
        logger
        validator
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            % Create a logger for testing
            testCase.logger = mlog.Logger('pipeline:test:ConfigValidator');
            testCase.logger.CommandWindowThreshold = mlog.Level.FATAL; % Suppress output during tests
            
            % Create validator instance
            testCase.validator = pipeline.utility.ConfigValidator(testCase.logger);
        end
    end
    
    methods (Test)
        
        %% Tests for validateLoggingConfig
        
        function testValidateLoggingConfig_NoLoggingSection(testCase)
            % Test that missing logging section is handled correctly
            config = struct();
            
            % Should not throw any error
            testCase.validator.validateLoggingConfig(config);
            testCase.verifyTrue(true, 'Should pass without logging section');
        end
        
        function testValidateLoggingConfig_ValidConsoleLevel(testCase, validLogLevels)
            % Test valid console log levels
            config = struct();
            config.logging = struct();
            config.logging.console_level = validLogLevels;
            
            testCase.validator.validateLoggingConfig(config);
            testCase.verifyTrue(true, sprintf('Should accept valid console level: %s', string(validLogLevels)));
        end
        
        function testValidateLoggingConfig_ValidFileLevel(testCase, validLogLevels)
            % Test valid file log levels (with filepath)
            config = struct();
            config.logging = struct();
            config.logging.file_level = validLogLevels;
            config.logging.filepath = 'test.log';
            
            testCase.validator.validateLoggingConfig(config);
            testCase.verifyTrue(true, sprintf('Should accept valid file level: %s', string(validLogLevels)));
        end
        
        function testValidateLoggingConfig_InvalidConsoleLevel(testCase, invalidLogLevels)
            % Test invalid console log levels
            config = struct();
            config.logging = struct();
            config.logging.console_level = invalidLogLevels;
            
            testCase.verifyError(@() testCase.validator.validateLoggingConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                sprintf('Should reject invalid console level: %s', string(invalidLogLevels)));
        end
        
        function testValidateLoggingConfig_InvalidFileLevel(testCase, invalidLogLevels)
            % Test invalid file log levels
            config = struct();
            config.logging = struct();
            config.logging.file_level = invalidLogLevels;
            config.logging.filepath = 'test.log';
            
            testCase.verifyError(@() testCase.validator.validateLoggingConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                sprintf('Should reject invalid file level: %s', string(invalidLogLevels)));
        end
        
        function testValidateLoggingConfig_LoggingNotStruct(testCase)
            % Test when logging is not a struct
            config = struct();
            config.logging = 'invalid';
            
            testCase.verifyError(@() testCase.validator.validateLoggingConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                'Should reject non-struct logging config');
        end
        
        function testValidateLoggingConfig_IncompleteFileConfig_MissingLevel(testCase)
            % Test incomplete file logging configuration - missing level
            config = struct();
            config.logging = struct();
            config.logging.filepath = 'test.log';
            % file_level is missing
            
            testCase.verifyError(@() testCase.validator.validateLoggingConfig(config), ...
                'pipeline:ConfigValidator:IncompleteLoggingConfig', ...
                'Should reject incomplete file logging config (missing level)');
        end
        
        function testValidateLoggingConfig_IncompleteFileConfig_MissingPath(testCase)
            % Test incomplete file logging configuration - missing filepath
            config = struct();
            config.logging = struct();
            config.logging.file_level = 'debug';
            % filepath is missing
            
            testCase.verifyError(@() testCase.validator.validateLoggingConfig(config), ...
                'pipeline:ConfigValidator:IncompleteLoggingConfig', ...
                'Should reject incomplete file logging config (missing filepath)');
        end
        
        function testValidateLoggingConfig_InvalidFilepath(testCase)
            % Test invalid filepath types
            config = struct();
            config.logging = struct();
            config.logging.filepath = 123;
            config.logging.file_level = 'debug';
            
            testCase.verifyError(@() testCase.validator.validateLoggingConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                'Should reject non-string filepath');
        end
        
        %% Tests for validateBasicConfig and its components
        
        function testValidateBasicConfig_ValidConfig(testCase)
            % Test with a completely valid configuration
            config = ConfigValidatorTest.createValidConfig();
            
            testCase.validator.validateBasicConfig(config);
            testCase.verifyTrue(true, 'Should accept valid configuration');
        end
        
        function testValidateSurfaceFields_MissingStages(testCase)
            % Test missing stages field
            config = struct();
            config.params = struct('globals', struct(), 'grid', struct());
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:MissingRequiredField', ...
                'Should reject config missing stages field');
        end
        
        function testValidateSurfaceFields_MissingParams(testCase)
            % Test missing params field
            config = struct();
            config.stages = struct();
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:MissingRequiredField', ...
                'Should reject config missing params field');
        end
        
        function testValidateSurfaceFields_MissingOutputFilename(testCase)
            % Test missing output_filename field
            config = struct();
            config.stages = struct();
            config.params = struct('globals', struct(), 'grid', struct());
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:MissingRequiredField', ...
                'Should reject config missing output_filename field');
        end
        
        function testValidateSurfaceFields_StagesNotStruct(testCase)
            % Test when stages is not a struct
            config = struct();
            config.stages = 'invalid';
            config.params = struct('globals', struct(), 'grid', struct());
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                'Should reject non-struct stages');
        end
        
        function testValidateSurfaceFields_ParamsNotStruct(testCase)
            % Test when params is not a struct
            config = struct();
            config.stages = struct();
            config.params = 'invalid';
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                'Should reject non-struct params');
        end
        
        function testValidateSurfaceFields_OutputFilenameNotString(testCase)
            % Test when output_filename is not a string
            config = struct();
            config.stages = struct();
            config.params = struct('globals', struct(), 'grid', struct());
            config.output_filename = 123;
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                'Should reject non-string output_filename');
        end
        
        function testValidateParameterSpace_MissingGlobals(testCase)
            % Test missing globals in params
            config = struct();
            config.stages = struct();
            config.params = struct('grid', struct());
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:MissingRequiredField', ...
                'Should reject config missing params.globals');
        end
        
        function testValidateParameterSpace_MissingGrid(testCase)
            % Test missing grid in params
            config = struct();
            config.stages = struct();
            config.params = struct('globals', struct());
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:MissingRequiredField', ...
                'Should reject config missing params.grid');
        end
        
        function testValidateParameterSpace_GlobalsNotStruct(testCase)
            % Test when globals is not a struct
            config = struct();
            config.stages = struct();
            config.params = struct('globals', 'invalid', 'grid', struct());
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                'Should reject non-struct globals');
        end
        
        function testValidateParameterSpace_GridNotStruct(testCase)
            % Test when grid is not a struct
            config = struct();
            config.stages = struct();
            config.params = struct('globals', struct(), 'grid', 'invalid');
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:InvalidFieldType', ...
                'Should reject non-struct grid');
        end
        
        function testValidateParameterSpace_ParameterNameCollision(testCase)
            % Test parameter name collision between globals and grid
            config = struct();
            config.stages = struct();
            config.params = struct();
            config.params.globals = struct('param1', 1, 'param2', 2);
            config.params.grid = struct('param2', [1, 2, 3], 'param3', [4, 5, 6]);
            config.output_filename = 'output.h5';
            
            testCase.verifyError(@() testCase.validator.validateBasicConfig(config), ...
                'pipeline:ConfigValidator:ParameterNameCollision', ...
                'Should reject parameter name collision');
        end
        
        function testCheckForUnexpectedFields_ValidFields(testCase)
            % Test that expected fields don't generate warnings
            config = ConfigValidatorTest.createValidConfig();
            config.logging = struct();
            config.error_mode = 'fail_fast';
            config.num_workers = 4;
            
            testCase.validator.validateBasicConfig(config);
            testCase.verifyTrue(true, 'Should accept all expected fields without warnings');
        end
        
        function testCheckForUnexpectedFields_UnexpectedField(testCase)
            % Test that unexpected fields generate warnings
            config = ConfigValidatorTest.createValidConfig();
            config.unexpected_field = 'should warn';
            
            % Note: Testing warning generation requires checking log output,
            % which is complex in unit tests. This test verifies the method
            % doesn't crash with unexpected fields.
            testCase.validator.validateBasicConfig(config);
            testCase.verifyTrue(true, 'Should handle unexpected fields gracefully');
        end
        
        %% Edge cases and integration tests
        
        function testValidateLoggingConfig_BothFileAndConsole(testCase)
            % Test valid configuration with both console and file logging
            config = struct();
            config.logging = struct();
            config.logging.console_level = 'info';
            config.logging.file_level = 'debug';
            config.logging.filepath = 'test.log';
            
            testCase.validator.validateLoggingConfig(config);
            testCase.verifyTrue(true, 'Should accept both console and file logging');
        end
        
        function testValidateLoggingConfig_OnlyConsole(testCase)
            % Test valid configuration with only console logging
            config = struct();
            config.logging = struct();
            config.logging.console_level = 'warning';
            
            testCase.validator.validateLoggingConfig(config);
            testCase.verifyTrue(true, 'Should accept console-only logging');
        end
        
        function testConstructor_WithLogger(testCase)
            % Test constructor properly stores logger
            testLogger = mlog.Logger('test:logger');
            testValidator = pipeline.utility.ConfigValidator(testLogger);
            
            % Verify the validator was created successfully
            testCase.verifyClass(testValidator, 'pipeline.utility.ConfigValidator');
        end
        
        function testValidateBasicConfig_EmptyStructs(testCase)
            % Test with empty but properly typed structs
            config = struct();
            config.stages = struct();
            config.params = struct('globals', struct(), 'grid', struct());
            config.output_filename = '';
            
            testCase.validator.validateBasicConfig(config);
            testCase.verifyTrue(true, 'Should accept empty but valid structs');
        end
        
        function testValidateBasicConfig_StringVsChar(testCase)
            % Test that both string and char arrays are accepted
            config1 = ConfigValidatorTest.createValidConfig();
            config1.output_filename = 'output.h5'; % char array
            
            config2 = ConfigValidatorTest.createValidConfig();
            config2.output_filename = string('output.h5'); % string
            
            testCase.validator.validateBasicConfig(config1);
            testCase.validator.validateBasicConfig(config2);
            testCase.verifyTrue(true, 'Should accept both char and string types');
        end
        
        %% Integration tests with real-world configuration
        
        function testValidateLoggingConfig_GenerateConfigExample(testCase)
            % Test validation of logging config from generate_config() example
            
            % Add the examples directory to path relative to test directory
            testDir = fileparts(mfilename('fullpath'));
            examplesDir = fullfile(testDir, '..', 'examples', 'extended_hankel_havok');
            addpath(examplesDir);
            
            try
                % Get the real configuration
                config = generate_config();
                
                % Should validate successfully
                testCase.validator.validateLoggingConfig(config);
                testCase.verifyTrue(true, 'Should accept generate_config() logging configuration');
                
                % Verify specific logging settings are as expected
                testCase.verifyTrue(isfield(config.logging, 'console_level'), ...
                    'generate_config should include console_level');
                testCase.verifyTrue(isfield(config.logging, 'file_level'), ...
                    'generate_config should include file_level');
                testCase.verifyTrue(isfield(config.logging, 'filepath'), ...
                    'generate_config should include filepath');
                
                % Verify values are valid
                testCase.verifyEqual(config.logging.console_level, 'info', ...
                    'Console level should be info');
                testCase.verifyEqual(config.logging.file_level, 'debug', ...
                    'File level should be debug');
                testCase.verifyEqual(config.logging.filepath, 'logs/havok_modular.log', ...
                    'Filepath should match expected value');
                    
            catch ME
                % Clean up path before rethrowing
                rmpath(examplesDir);
                rethrow(ME);
            end
            
            % Clean up path
            rmpath(examplesDir);
        end
        
        function testValidateBasicConfig_GenerateConfigExample(testCase)
            % Test comprehensive validation of the generate_config() example
            
            % Add the examples directory to path relative to test directory
            testDir = fileparts(mfilename('fullpath'));
            examplesDir = fullfile(testDir, '..', 'examples', 'extended_hankel_havok');
            addpath(examplesDir);
            
            try
                % Get the real configuration
                config = generate_config();
                
                % Should validate successfully
                testCase.validator.validateBasicConfig(config);
                testCase.verifyTrue(true, 'Should accept generate_config() basic configuration');
                
                % Verify all required top-level fields are present
                testCase.verifyTrue(isfield(config, 'stages'), ...
                    'generate_config should include stages');
                testCase.verifyTrue(isfield(config, 'params'), ...
                    'generate_config should include params');
                testCase.verifyTrue(isfield(config, 'output_filename'), ...
                    'generate_config should include output_filename');
                
                % Verify parameter structure
                testCase.verifyTrue(isfield(config.params, 'globals'), ...
                    'params should include globals');
                testCase.verifyTrue(isfield(config.params, 'grid'), ...
                    'params should include grid');
                testCase.verifyTrue(isfield(config.params, 'filter'), ...
                    'params should include filter function');
                
                % Verify no parameter name collisions
                global_names = fieldnames(config.params.globals);
                grid_names = fieldnames(config.params.grid);
                common_names = intersect(global_names, grid_names);
                testCase.verifyEmpty(common_names, ...
                    'No parameter name collisions should exist between globals and grid');
                
            catch ME
                % Clean up path before rethrowing
                rmpath(examplesDir);
                rethrow(ME);
            end
            
            % Clean up path
            rmpath(examplesDir);
        end
        
        function testValidateGenerateConfig_ParameterTypes(testCase)
            % Test that parameter types in generate_config() are valid
            
            % Add the examples directory to path relative to test directory
            testDir = fileparts(mfilename('fullpath'));
            examplesDir = fullfile(testDir, '..', 'examples', 'extended_hankel_havok');
            addpath(examplesDir);
            
            try
                % Get the real configuration
                config = generate_config();
                
                % Verify globals are scalars as required
                globals = config.params.globals;
                global_fields = fieldnames(globals);
                
                for i = 1:length(global_fields)
                    field_name = global_fields{i};
                    field_value = globals.(field_name);
                    testCase.verifyTrue(isscalar(field_value), ...
                        sprintf('Global parameter %s should be scalar, got %s', ...
                        field_name, mat2str(size(field_value))));
                end
                
                % Verify grid parameters are arrays
                grid = config.params.grid;
                grid_fields = fieldnames(grid);
                
                for i = 1:length(grid_fields)
                    field_name = grid_fields{i};
                    field_value = grid.(field_name);
                    % Grid parameters can be vectors or cell arrays
                    testCase.verifyTrue(isvector(field_value) || iscell(field_value), ...
                        sprintf('Grid parameter %s should be vector or cell array', field_name));
                end
                
                % Verify filter function is callable
                testCase.verifyTrue(isa(config.params.filter, 'function_handle'), ...
                    'Filter should be a function handle');
                
            catch ME
                % Clean up path before rethrowing
                rmpath(examplesDir);
                rethrow(ME);
            end
            
            % Clean up path
            rmpath(examplesDir);
        end
        
        function testValidateGenerateConfig_StageStructure(testCase)
            % Test that stage definitions in generate_config() are well-formed
            
            % Add the examples directory to path relative to test directory
            testDir = fileparts(mfilename('fullpath'));
            examplesDir = fullfile(testDir, '..', 'examples', 'extended_hankel_havok');
            addpath(examplesDir);
            
            try
                % Get the real configuration
                config = generate_config();
                
                % Verify stages structure
                stages = config.stages;
                stage_names = fieldnames(stages);
                
                testCase.verifyGreaterThan(length(stage_names), 0, ...
                    'Should have at least one stage defined');
                
                % Check each stage has expected structure
                for i = 1:length(stage_names)
                    stage_name = stage_names{i};
                    stage_array = stages.(stage_name);
                    
                    testCase.verifyTrue(isstruct(stage_array), ...
                        sprintf('Stage %s should be a struct array', stage_name));
                    
                    % Check each element in the stage array
                    for k = 1:length(stage_array)
                        stage_def = stage_array(k);
                        
                        % Verify function handle exists
                        testCase.verifyTrue(isfield(stage_def, 'function'), ...
                            sprintf('Stage %s element %d should have function field', stage_name, k));
                        stage_func = stage_def.function;
                        testCase.verifyTrue(isa(stage_func, 'function_handle'), 'Stage function should be a function handle');
                        
                        % Verify params field if present
                        if isfield(stage_def, 'params')
                            stage_params = stage_def.params;
                            % Params can be various types, just verify it exists
                            testCase.verifyTrue(~isempty(stage_params), 'Stage params should not be empty if present');
                        end
                        
                        % Verify outputs field if present
                        if isfield(stage_def, 'outputs')
                            stage_outputs = stage_def.outputs;
                            
                            if isstruct(stage_outputs)
                                % Single struct output
                                testCase.verifyTrue(isfield(stage_outputs, 'name'), 'Stage output should have name field');
                                testCase.verifyTrue(isfield(stage_outputs, 'storage_policy'), 'Stage output should have storage_policy field');
                            elseif iscell(stage_outputs)
                                % Cell array of struct outputs
                                for j = 1:length(stage_outputs)
                                    output_def = stage_outputs{j};
                                    testCase.verifyTrue(isstruct(output_def), 'Stage output should be a struct');
                                    testCase.verifyTrue(isfield(output_def, 'name'), 'Stage output should have name field');
                                    testCase.verifyTrue(isfield(output_def, 'storage_policy'), 'Stage output should have storage_policy field');
                                end
                            else
                                testCase.verifyFail('Stage outputs should be either struct or cell array');
                            end
                        end
                        
                        % Verify execution_mode if present
                        if isfield(stage_def, 'execution_mode')
                            valid_modes = {'per_run', 'global'};
                            exec_mode = stage_def.execution_mode;
                            testCase.verifyTrue(ismember(exec_mode, valid_modes), 'Stage execution_mode should be per_run or global');
                        end
                    end
                end
                
            catch ME
                % Clean up path before rethrowing
                rmpath(examplesDir);
                rethrow(ME);
            end
            
            % Clean up path
            rmpath(examplesDir);
        end
        
        function testValidateGenerateConfig_OptionalFields(testCase)
            % Test that optional fields in generate_config() are valid when present
            
            % Add the examples directory to path relative to test directory
            testDir = fileparts(mfilename('fullpath'));
            examplesDir = fullfile(testDir, '..', 'examples', 'extended_hankel_havok');
            addpath(examplesDir);
            
            try
                % Get the real configuration
                config = generate_config();
                
                % Test error_mode if present
                if isfield(config, 'error_mode')
                    valid_error_modes = {'resilient', 'fail_fast'};
                    testCase.verifyTrue(ismember(config.error_mode, valid_error_modes), ...
                        'error_mode should be resilient or fail_fast');
                end
                
                % Test num_workers if present
                if isfield(config, 'num_workers')
                    testCase.verifyTrue(isnumeric(config.num_workers), ...
                        'num_workers should be numeric');
                    testCase.verifyTrue(config.num_workers > 0, ...
                        'num_workers should be positive');
                end
                
                % Verify overall structure passes both logging and basic validation
                testCase.validator.validateLoggingConfig(config);
                testCase.validator.validateBasicConfig(config);
                
                testCase.verifyTrue(true, 'generate_config() should pass complete validation');
                
            catch ME
                % Clean up path before rethrowing
                rmpath(examplesDir);
                rethrow(ME);
            end
            
            % Clean up path
            rmpath(examplesDir);
        end
        
    end % methods (Test)
    
    methods (Static, Access = private)
        function config = createValidConfig()
            % Helper method to create a valid basic configuration
            config = struct();
            config.stages = struct();
            config.params = struct();
            config.params.globals = struct();
            config.params.grid = struct();
            config.output_filename = 'output.h5';
        end
    end % methods (Static, Access = private)
    
end % classdef
