classdef TestNumericalDerivative < matlab.unittest.TestCase
    
    % Unit tests for the numerical_derivative function
    methods (TestClassSetup)
        function addUtilsToPath(testCase)
            % Ensure the utils directory is on the MATLAB path
            utilsDir = fileparts(mfilename('fullpath'));
            addpath(utilsDir);
        end
    end
    methods (Test)
        function testSineWave(testCase)
            t = 0:0.1:2*pi;
            dt = 0.1;
            test_data = sin(t)';
            analytical_derivative = cos(t)';
            dV_3 = numerical_derivative(test_data, dt, 'num_points', 3);
            dV_5 = numerical_derivative(test_data, dt);
            valid_indices_3 = 2:length(t)-1;
            valid_indices_45 = 3:length(t)-2;
            error_3 = mean(abs(dV_3(valid_indices_3) - analytical_derivative(valid_indices_3)));
            error_5 = mean(abs(dV_5(valid_indices_45) - analytical_derivative(valid_indices_45)));
            testCase.verifyLessThan(error_5, error_3, '5-point should be more accurate than 3-point');
        end

        function testPolynomialFunction(testCase)
            t = 0:0.1:5;
            dt = 0.1;
            poly_data = t.^3 - 2*t.^2 + 3*t + 1;
            poly_data = poly_data';
            analytical_poly_deriv = (3*t.^2 - 4*t + 3)';
            dV_poly = numerical_derivative(poly_data, dt, 'num_points', 5);
            valid_indices = 3:length(t)-2;
            poly_error = mean(abs(dV_poly(valid_indices) - analytical_poly_deriv(valid_indices)));
            testCase.verifyLessThan(poly_error, dt^4, 'Polynomial derivative should be very accurate');
        end

        function testMultiColumnMatrix(testCase)
            t = 0:0.1:2*pi;
            dt = 0.1;
            multi_data = [sin(t)', cos(t)', t'.^2];
            analytical_multi = [cos(t)', -sin(t)', 2*t'];
            dV_multi = numerical_derivative(multi_data, dt, 'num_points', 5);
            valid_indices = 3:length(t)-2;
            for col = 1:3
                col_error = mean(abs(dV_multi(valid_indices, col) - analytical_multi(valid_indices, col)));
                testCase.verifyLessThan(col_error, dt^4, sprintf('Column %d error too high', col));
            end
        end

        function testEdgeCasesAndErrorHandling(testCase)
            % Small matrix (3 points)
            small_data = [1; 2; 3];
            testCase.verifyWarningFree(@() numerical_derivative(small_data, 0.1, 'num_points', 3));
            % Invalid order
            t = 0:0.1:2*pi;
            dt = 0.1;
            test_data = sin(t)';
            f = @() numerical_derivative(test_data, dt, 'num_points', 2);
            testCase.verifyError(f, '', 'Order must be 3, 4, or 5');
            % compute_endpoints option (not implemented)
            f2 = @() numerical_derivative(test_data, dt, 'compute_endpoints', true);
            testCase.verifyError(f2, '', 'Not implemented');
            % Negative dt
            f3 = @() numerical_derivative(test_data, -0.1);
            testCase.verifyError(f3, 'MATLAB:validators:mustBePositive', 'Time step dt must be positive');
        end

        function testAccuracyComparison(testCase)
            t = 0:0.01:2*pi;
            dt = 0.01;
            test_func = exp(t)';
            analytical_exp = exp(t)';
            dV_exp_3 = numerical_derivative(test_func, dt, 'num_points', 3);
            dV_exp_5 = numerical_derivative(test_func, dt, 'num_points', 5);
            mid_start = round(length(t)/4);
            mid_end = round(3*length(t)/4);
            valid_3 = max(2, mid_start):min(length(t)-1, mid_end);
            valid_45 = max(3, mid_start):min(length(t)-2, mid_end);
            error_exp_3 = mean(abs(dV_exp_3(valid_3) - analytical_exp(valid_3)));
            error_exp_5 = mean(abs(dV_exp_5(valid_45) - analytical_exp(valid_45)));
            testCase.verifyLessThan(error_exp_5, error_exp_3, '5-point should be more accurate than 3-point');
        end

        function testBoundaryBehavior(testCase)
            t = 0:0.1:2;
            dt = 0.1;
            test_data = t'.^2;
            dV_boundary = numerical_derivative(test_data, dt, 'num_points', 5);
            testCase.verifyEqual(dV_boundary(1), 0, 'First point should be zero');
            testCase.verifyEqual(dV_boundary(2), 0, 'Second point should be zero');
            testCase.verifyEqual(dV_boundary(end-1), 0, 'Second-to-last point should be zero');
            testCase.verifyEqual(dV_boundary(end), 0, 'Last point should be zero');
        end
    end
end
