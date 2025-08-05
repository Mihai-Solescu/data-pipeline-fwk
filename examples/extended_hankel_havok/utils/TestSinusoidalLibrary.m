classdef TestSinusoidalLibrary < matlab.unittest.TestCase
    % Unit tests for the sinusoidal_library function
    methods (TestClassSetup)
        function addUtilsToPath(~)
            utilsDir = fileparts(mfilename('fullpath'));
            addpath(utilsDir);
        end
    end
    methods (Test)
        function testBasic2DSinusoidal(testCase)
            xdat = [0 pi/2; pi/4 3*pi/4; pi/2 pi]; max_harmonics = 1;
            [Theta, column_names] = sinusoidal_library(xdat, 'nVars', 2, 'max_harmonics', max_harmonics);
            expected_Theta = [0 1 1 0; sqrt(2)/2 sqrt(2)/2 sqrt(2)/2 -sqrt(2)/2; 1 0 0 -1];
            expected_names = {'sin(x_1)','sin(x_2)','cos(x_1)','cos(x_2)'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function testKnownMathematicalValues(testCase)
            xdat = [0 pi/2; pi/6 pi/3]; max_harmonics = 2;
            [Theta, column_names] = sinusoidal_library(xdat, 'nVars', 2, 'max_harmonics', max_harmonics);
            row1 = [0 1 1 0 0 0 1 -1];
            row2 = [1/2 sqrt(3)/2 sqrt(3)/2 1/2 sqrt(3)/2 sqrt(3)/2 1/2 -1/2];
            expected_Theta = [row1; row2];
            expected_names = {'sin(x_1)','sin(x_2)','cos(x_1)','cos(x_2)','sin(2*x_1)','sin(2*x_2)','cos(2*x_1)','cos(2*x_2)'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function testSubsetOfVariables(testCase)
            xdat = [1 2 3; 4 5 6; 7 8 9];
            [Theta, column_names] = sinusoidal_library(xdat, 'nVars', 2, 'max_harmonics', 1);
            testCase.verifyEqual(size(Theta,2), 4);
            testCase.verifyEqual(length(column_names), 4);
        end
        % Add more tests as needed for further coverage
    end
end
