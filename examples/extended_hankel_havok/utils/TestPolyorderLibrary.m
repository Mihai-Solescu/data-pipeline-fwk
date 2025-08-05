classdef TestPolyorderLibrary < matlab.unittest.TestCase
    % Unit tests for the polyorder_library function
    methods (TestClassSetup)
        function addUtilsToPath(~)
            utilsDir = fileparts(mfilename('fullpath'));
            addpath(utilsDir);
        end
    end
    methods (Test)
        function test2DQuadraticWithCrossTerms(testCase)
            xdat = [2 3; 4 5]; polyorder = 2;
            [Theta, column_names] = polyorder_library(xdat, polyorder);
            x1 = xdat(:,1); x2 = xdat(:,2);
            expected_Theta = [ones(size(x1)), x1, x2, x1.^2, x1.*x2, x2.^2];
            expected_names = {'1','x_1','x_2','x_1^2','x_1*x_2','x_2^2'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function testPurePowersNoCrossTerms(testCase)
            xdat = [1 2; 3 4]; polyorder = 3;
            [Theta, column_names] = polyorder_library(xdat, polyorder, 'use_cross_terms', false);
            x1 = xdat(:,1); x2 = xdat(:,2);
            expected_Theta = [ones(size(x1)), x1, x2, x1.^2, x2.^2, x1.^3, x2.^3];
            expected_names = {'1','x_1','x_2','x_1^2','x_2^2','x_1^3','x_2^3'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function test3DQuadraticWithCrossTerms(testCase)
            xdat = [1 2 1; 2 1 3]; polyorder = 2;
            [Theta, column_names] = polyorder_library(xdat, polyorder, 'use_cross_terms', true);
            x1 = xdat(:,1); x2 = xdat(:,2); x3 = xdat(:,3);
            expected_Theta = [ones(size(x1)), x1, x2, x3, x1.^2, x1.*x2, x1.*x3, x2.^2, x2.*x3, x3.^2];
            expected_names = {'1','x_1','x_2','x_3','x_1^2','x_1*x_2','x_1*x_3','x_2^2','x_2*x_3','x_3^2'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function test2DCubicAllCrossTerms(testCase)
            xdat = [2 1]; polyorder = 3;
            [Theta, column_names] = polyorder_library(xdat, polyorder, 'use_cross_terms', true);
            x1 = 2; x2 = 1;
            expected_Theta = [1, x1, x2, x1^2, x1*x2, x2^2, x1^3, x1^2*x2, x1*x2^2, x2^3];
            expected_names = {'1','x_1','x_2','x_1^2','x_1*x_2','x_2^2','x_1^3','x_1^2*x_2','x_1*x_2^2','x_2^3'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function testLinearPolynomial(testCase)
            xdat = [3 4 5; 6 7 8]; polyorder = 1;
            [Theta, column_names] = polyorder_library(xdat, polyorder);
            x1 = xdat(:,1); x2 = xdat(:,2); x3 = xdat(:,3);
            expected_Theta = [ones(size(x1)), x1, x2, x3];
            expected_names = {'1','x_1','x_2','x_3'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function testSingleVariablePolynomial(testCase)
            xdat = [2;3;4]; polyorder = 4;
            [Theta, column_names] = polyorder_library(xdat, polyorder);
            x1 = xdat(:,1);
            expected_Theta = [ones(size(x1)), x1, x1.^2, x1.^3, x1.^4];
            expected_names = {'1','x_1','x_1^2','x_1^3','x_1^4'};
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(column_names, expected_names);
        end
        function testCrossTermsVsPurePowersFeatureCount(testCase)
            xdat = [1 2 3]; polyorder = 2;
            [Theta_cross, names_cross] = polyorder_library(xdat, polyorder, 'use_cross_terms', true);
            [Theta_pure, names_pure] = polyorder_library(xdat, polyorder, 'use_cross_terms', false);
            testCase.verifyEqual(size(Theta_cross,2), 10);
            testCase.verifyEqual(size(Theta_pure,2), 7);
            testCase.verifyEqual(length(names_cross), 10);
            testCase.verifyEqual(length(names_pure), 7);
            testCase.verifyEqual(Theta_cross(:,1:4), Theta_pure(:,1:4));
        end
        function testMathematicalIdentityVerification(testCase)
            xdat = [0 1; 1 0; 1 1; -1 1]; polyorder = 2;
            [Theta, ~] = polyorder_library(xdat, polyorder);
            expected_Theta = [1 0 1 0 0 1; 1 1 0 1 0 0; 1 1 1 1 1 1; 1 -1 1 1 -1 1];
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-10);
            testCase.verifyEqual(Theta(1,2), 0);
            testCase.verifyEqual(Theta(3,5), 1);
            testCase.verifyEqual(Theta(4,2), -1);
            testCase.verifyEqual(Theta(4,4), 1);
        end
        function testLargeDimensionScaling(testCase)
            xdat = rand(5,4); polyorder = 2;
            [Theta_cross, ~] = polyorder_library(xdat, polyorder, 'use_cross_terms', true);
            [Theta_pure, ~] = polyorder_library(xdat, polyorder, 'use_cross_terms', false);
            testCase.verifyEqual(size(Theta_cross,2), 15);
            testCase.verifyEqual(size(Theta_pure,2), 9);
            testCase.verifyEqual(size(Theta_cross,1), 5);
            testCase.verifyEqual(size(Theta_pure,1), 5);
        end
        function testColumnNameFormatting(testCase)
            xdat = [1 2 3]; polyorder = 2;
            [~, column_names] = polyorder_library(xdat, polyorder, 'use_cross_terms', true);
            expected_names = {'1','x_1','x_2','x_3','x_1^2','x_1*x_2','x_1*x_3','x_2^2','x_2*x_3','x_3^2'};
            testCase.verifyEqual(column_names, expected_names);
            testCase.verifyEqual(column_names{1}, '1');
            testCase.verifyEqual(column_names{2}, 'x_1');
            testCase.verifyEqual(column_names{5}, 'x_1^2');
            testCase.verifyEqual(column_names{6}, 'x_1*x_2');
        end
        function testNumericalPrecisionWithFractions(testCase)
            xdat = [0.5 0.25; 0.75 0.125]; polyorder = 2;
            [Theta, ~] = polyorder_library(xdat, polyorder);
            expected_Theta = [1 0.5 0.25 0.25 0.125 0.0625; 1 0.75 0.125 0.5625 0.09375 0.015625];
            testCase.verifyEqual(size(Theta), size(expected_Theta));
            testCase.verifyLessThan(max(abs(Theta(:)-expected_Theta(:))), 1e-15);
            testCase.verifyLessThan(abs(Theta(1,4)-0.5^2), 1e-15);
            testCase.verifyLessThan(abs(Theta(1,5)-0.5*0.25), 1e-15);
            testCase.verifyLessThan(abs(Theta(2,6)-0.125^2), 1e-15);
        end
        function testCrossProductProperties(testCase)
            xdat = [2 3; 0 5; 1 0]; polyorder = 2;
            [Theta, ~] = polyorder_library(xdat, polyorder);
            expected_cross = [6;0;0];
            testCase.verifyEqual(Theta(:,5), expected_cross);
            testCase.verifyEqual(Theta(2,5), 0);
            testCase.verifyEqual(Theta(3,5), 0);
        end
        function testFeatureCountingFormula(testCase)
            test_cases = [1 1 1 2; 1 2 1 3; 1 3 1 4; 2 1 1 3; 2 2 1 6; 2 3 1 10; 3 1 1 4; 3 2 1 10; 2 2 0 5; 3 2 0 7; 4 2 0 9; 1 4 0 5];
            for i = 1:size(test_cases,1)
                d = test_cases(i,1); polyorder = test_cases(i,2); use_cross = logical(test_cases(i,3)); expected = test_cases(i,4);
                test_data = ones(5,d);
                [Theta, names] = polyorder_library(test_data, polyorder, 'use_cross_terms', use_cross);
                testCase.verifyEqual(size(Theta,2), expected);
                testCase.verifyEqual(length(names), expected);
            end
        end
        function testErrorHandling(testCase)
            testCase.verifyError(@() polyorder_library([1 2; 3 4], 0), 'MATLAB:validators:mustBePositive');
            testCase.verifyError(@() polyorder_library([], 2), 'MATLAB:validators:mustBeNonempty');
        end
    end
end
