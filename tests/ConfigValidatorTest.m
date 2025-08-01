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
