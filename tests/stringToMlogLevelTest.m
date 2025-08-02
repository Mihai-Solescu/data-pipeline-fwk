classdef stringToMlogLevelTest < matlab.unittest.TestCase
    % stringToMlogLevelTest Unit tests for the stringToMlogLevel utility function
    % This test file validates the conversion of string representations to
    % mlog.Level enumerations for all valid levels and error handling for
    % invalid inputs.
    
    properties (TestParameter)
        % All valid mlog.Level enumeration values with their string representations
        validLevelData = struct(...
            'none', {{"NONE", mlog.Level.NONE}}, ...
            'fatal', {{"FATAL", mlog.Level.FATAL}}, ...
            'critical', {{"CRITICAL", mlog.Level.CRITICAL}}, ...
            'error', {{"ERROR", mlog.Level.ERROR}}, ...
            'warning', {{"WARNING", mlog.Level.WARNING}}, ...
            'info', {{"INFO", mlog.Level.INFO}}, ...
            'message', {{"MESSAGE", mlog.Level.MESSAGE}}, ...
            'debug', {{"DEBUG", mlog.Level.DEBUG}}, ...
            'detail', {{"DETAIL", mlog.Level.DETAIL}}, ...
            'trace', {{"TRACE", mlog.Level.TRACE}} ...
        )
        
        % Valid levels with mixed case to test case insensitivity
        mixedCaseLevelData = struct(...
            'none_lower', {{"none", mlog.Level.NONE}}, ...
            'fatal_lower', {{"fatal", mlog.Level.FATAL}}, ...
            'critical_mixed', {{"Critical", mlog.Level.CRITICAL}}, ...
            'error_mixed', {{"Error", mlog.Level.ERROR}}, ...
            'warning_mixed', {{"Warning", mlog.Level.WARNING}}, ...
            'info_lower', {{"info", mlog.Level.INFO}}, ...
            'message_mixed', {{"Message", mlog.Level.MESSAGE}}, ...
            'debug_lower', {{"debug", mlog.Level.DEBUG}}, ...
            'detail_mixed', {{"Detail", mlog.Level.DETAIL}}, ...
            'trace_mixed', {{"Trace", mlog.Level.TRACE}} ...
        )
        
        % Invalid level strings that should cause errors
        invalidLevelStrings = {"INVALID", "UNKNOWN", "LOG", "LEVEL", "", " ", ...
                              "none ", " none", "123", "INFO_EXTRA", "null", ...
                              "undefined", "verbose", "warn", "err"}
    end
    
    methods (Test)
        
        function testValidLevelsUpperCase(testCase, validLevelData)
            % Test conversion of all valid uppercase level strings
            levelStr = validLevelData{1};
            expectedLevel = validLevelData{2};
            
            actualLevel = pipeline.utility.stringToMlogLevel(levelStr);
            
            testCase.verifyEqual(actualLevel, expectedLevel, ...
                sprintf('Failed to convert "%s" to correct mlog.Level', levelStr));
        end
        
        function testValidLevelsMixedCase(testCase, mixedCaseLevelData)
            % Test conversion of valid level strings with mixed case
            levelStr = mixedCaseLevelData{1};
            expectedLevel = mixedCaseLevelData{2};
            
            actualLevel = pipeline.utility.stringToMlogLevel(levelStr);
            
            testCase.verifyEqual(actualLevel, expectedLevel, ...
                sprintf('Failed to convert mixed case "%s" to correct mlog.Level', levelStr));
        end
        
        function testInvalidLevelStrings(testCase, invalidLevelStrings)
            % Test that invalid level strings throw the correct error
            levelStr = invalidLevelStrings;
            
            testCase.verifyError(@() pipeline.utility.stringToMlogLevel(levelStr), ...
                'pipeline:utility:InvalidLogLevel', ...
                sprintf('Expected error for invalid level string "%s"', levelStr));
        end
        
        function testReturnTypesAreCorrect(testCase)
            % Test that all returned values are of type mlog.Level
            validLevels = ["NONE", "FATAL", "CRITICAL", "ERROR", "WARNING", ...
                          "INFO", "MESSAGE", "DEBUG", "DETAIL", "TRACE"];
            
            for i = 1:length(validLevels)
                result = pipeline.utility.stringToMlogLevel(validLevels(i));
                testCase.verifyClass(result, 'mlog.Level', ...
                    sprintf('Result for "%s" should be of class mlog.Level', validLevels(i)));
            end
        end
        
        function testAllEnumerationMembersHandled(testCase)
            % Test that the function handles all members of mlog.Level enumeration
            % This test ensures we haven't missed any levels in our test data
            
            % Get all enumeration members
            allLevels = enumeration('mlog.Level');
            
            for i = 1:length(allLevels)
                levelName = string(allLevels(i));
                
                % Convert string back to enum using our function
                result = pipeline.utility.stringToMlogLevel(levelName);
                
                testCase.verifyEqual(result, allLevels(i), ...
                    sprintf('Failed round-trip conversion for level "%s"', levelName));
            end
        end
        
        function testStringInputValidation(testCase)
            % Test that non-string inputs are handled correctly by MATLAB's
            % argument validation (should produce appropriate error)
            
            % Test array size validation
            testCase.verifyError(@() pipeline.utility.stringToMlogLevel([]), ...
                'MATLAB:validation:IncompatibleSize', ...
                'Should reject empty array input');
            
            % Test type conversion validation  
            testCase.verifyError(@() pipeline.utility.stringToMlogLevel(struct()), ...
                'MATLAB:validation:UnableToConvert', ...
                'Should reject struct input');
            
            % Test multi-element cell array (should fail size validation)
            testCase.verifyError(@() pipeline.utility.stringToMlogLevel({'TRACE', 'INFO'}), ...
                'MATLAB:validation:IncompatibleSize', ...
                'Should reject multi-element cell array input');
            
            % Single-element cell array with valid level is actually allowed by MATLAB
            % so we verify it works correctly
            result = pipeline.utility.stringToMlogLevel({'TRACE'});
            testCase.verifyEqual(result, mlog.Level.TRACE, ...
                'Single-element cell array with valid level should work');
            
            % Test inputs that convert to string but are invalid levels
            testCase.verifyError(@() pipeline.utility.stringToMlogLevel(true), ...
                'pipeline:utility:InvalidLogLevel', ...
                'Should reject logical input that converts to invalid level string');
        end
        
        function testErrorMessageContent(testCase)
            % Test that error messages contain the invalid level string
            invalidLevel = "INVALID_LEVEL";
            
            try
                pipeline.utility.stringToMlogLevel(invalidLevel);
                testCase.verifyFail('Expected function to throw an error');
            catch ME
                testCase.verifyEqual(ME.identifier, 'pipeline:utility:InvalidLogLevel');
                testCase.verifySubstring(ME.message, invalidLevel, ...
                    'Error message should contain the invalid level string');
            end
        end
        
        function testCaseInsensitivityComprehensive(testCase)
            % Comprehensive test of case insensitivity across all valid levels
            baseLevel = "INFO";
            variations = [baseLevel, lower(baseLevel), ...
                         "Info", "iNfO", "InFo", "iNFO"];
            
            expectedLevel = mlog.Level.INFO;
            
            for i = 1:length(variations)
                result = pipeline.utility.stringToMlogLevel(variations(i));
                testCase.verifyEqual(result, expectedLevel, ...
                    sprintf('Case variation "%s" should convert to INFO level', variations(i)));
            end
        end
        
        function testEmptyAndWhitespaceStrings(testCase)
            % Test handling of empty and whitespace-only strings
            invalidInputs = ["", " ", "  ", "	"]; % last one is tab
            
            for i = 1:length(invalidInputs)
                testCase.verifyError(@() pipeline.utility.stringToMlogLevel(invalidInputs(i)), ...
                    'pipeline:utility:InvalidLogLevel', ...
                    sprintf('Should reject whitespace input "%s"', invalidInputs(i)));
            end
            
            % Test string.empty separately as it may behave differently
            try
                pipeline.utility.stringToMlogLevel(string.empty);
                testCase.verifyFail('Expected function to throw an error for string.empty');
            catch ME
                testCase.verifyTrue(contains(ME.identifier, 'validation') || ...
                                   strcmp(ME.identifier, 'pipeline:utility:InvalidLogLevel'), ...
                                   'Should reject string.empty input with appropriate error');
            end
        end
        
    end % methods (Test)
    
end % classdef
