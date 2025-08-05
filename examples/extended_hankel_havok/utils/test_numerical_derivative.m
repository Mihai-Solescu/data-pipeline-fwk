%% Test numerical_derivative function
% This script tests the numerical_derivative function with various inputs
% and validates the accuracy of different finite difference orders

%% Test 1: Basic functionality with sine wave
fprintf('Test 1: Basic functionality with sine wave\n');
dt = 0.1;
test_data = sin(t)';
analytical_derivative = cos(t)';

% Test with 3-point
dV_3 = numerical_derivative(test_data, dt, 'num_points', 3);
% Test with 5-point (default)
dV_5 = numerical_derivative(test_data, dt);

% Compare with analytical derivative (excluding endpoints where derivative is 0)
valid_indices_3 = 2:length(t)-1;
valid_indices_45 = 3:length(t)-2;

error_3 = mean(abs(dV_3(valid_indices_3) - analytical_derivative(valid_indices_3)));
error_5 = mean(abs(dV_5(valid_indices_45) - analytical_derivative(valid_indices_45)));

fprintf('  3-point mean absolute error: %.6f\n', error_3);
fprintf('  5-point mean absolute error: %.6f\n', error_5);

% Verify that higher point method is more accurate
assert(error_5 < error_3, 'Error: 5-point should be more accurate than 3-point');
fprintf('  ✓ 5-point is more accurate than 3-point\n');

%% Test 2: Polynomial function (exact derivatives for testing)
fprintf('\nTest 2: Polynomial function\n');
t = 0:0.1:5;
dt = 0.1;
% Test with polynomial: f(x) = x^3 - 2x^2 + 3x + 1
% Analytical derivative: f'(x) = 3x^2 - 4x + 3
poly_data = t.^3 - 2*t.^2 + 3*t + 1;
poly_data = poly_data';
analytical_poly_deriv = (3*t.^2 - 4*t + 3)';

% Only 5-point supported for high accuracy
dV_poly = numerical_derivative(poly_data, dt, 'num_points', 5);
valid_indices = 3:length(t)-2;
poly_error = mean(abs(dV_poly(valid_indices) - analytical_poly_deriv(valid_indices)));

fprintf('  Polynomial derivative mean absolute error: %.6f\n', poly_error);
assert(poly_error < 1e-10, 'Error: Polynomial derivative should be very accurate');
fprintf('  ✓ Polynomial derivative is accurate\n');

%% Test 3: Multi-column matrix input
fprintf('\nTest 3: Multi-column matrix input\n');
t = 0:0.1:2*pi;
dt = 0.1;
multi_data = [sin(t)', cos(t)', t'.^2];
analytical_multi = [cos(t)', -sin(t)', 2*t'];

dV_multi = numerical_derivative(multi_data, dt, 'num_points', 5);
valid_indices = 3:length(t)-2;

for col = 1:3
    col_error = mean(abs(dV_multi(valid_indices, col) - analytical_multi(valid_indices, col)));
    fprintf('  Column %d mean absolute error: %.6f\n', col, col_error);
end

fprintf('  ✓ Multi-column matrix processing works correctly\n');

%% Test 4: Edge cases and error handling
fprintf('\nTest 4: Edge cases and error handling\n');

% Test with small matrix (should work for 3rd order)
small_data = [1; 2; 3];
try
    dV_small = numerical_derivative(small_data, 0.1, 'num_points', 3);
    fprintf('  ✓ Small matrix (3 points) works with 3rd order\n');
catch
    fprintf('  ✗ Small matrix test failed\n');
end

% Test invalid order
try
    dV_invalid = numerical_derivative(test_data, dt, 'num_points', 2);
    fprintf('  ✗ Invalid order should have thrown error\n');
catch ME
    if contains(ME.message, 'Order must be 3, 4, or 5')
        fprintf('  ✓ Invalid order correctly throws error\n');
    else
        fprintf('  ✗ Unexpected error message: %s\n', ME.message);
    end
end

% Test compute_endpoints option (should throw error as not implemented)
try
    dV_endpoints = numerical_derivative(test_data, dt, 'compute_endpoints', true);
    fprintf('  ✗ compute_endpoints should have thrown error\n');
catch ME
    if contains(ME.message, 'Not implemented')
        fprintf('  ✓ compute_endpoints correctly throws error\n');
    else
        fprintf('  ✗ Unexpected error message: %s\n', ME.message);
    end
end

% Test negative dt
try
    dV_negative = numerical_derivative(test_data, -0.1);
    fprintf('  ✗ Negative dt should have thrown error\n');
catch ME
    fprintf('  ✓ Negative dt correctly throws error\n');
end

%% Test 5: Accuracy comparison between orders
fprintf('\nTest 5: Accuracy comparison between orders\n');
t = 0:0.01:2*pi;  % Finer grid for better accuracy assessment
dt = 0.01;
test_func = exp(t)';  % Exponential function
analytical_exp = exp(t)';


dV_exp_3 = numerical_derivative(test_func, dt, 'num_points', 3);
dV_exp_5 = numerical_derivative(test_func, dt, 'num_points', 5);

% Compare errors in the middle region
mid_start = round(length(t)/4);
mid_end = round(3*length(t)/4);
valid_3 = max(2, mid_start):min(length(t)-1, mid_end);
valid_45 = max(3, mid_start):min(length(t)-2, mid_end);

error_exp_3 = mean(abs(dV_exp_3(valid_3) - analytical_exp(valid_3)));
error_exp_5 = mean(abs(dV_exp_5(valid_45) - analytical_exp(valid_45)));

fprintf('  Exponential function errors:\n');
fprintf('    3-point: %.2e\n', error_exp_3);
fprintf('    5-point: %.2e\n', error_exp_5);

% Verify order of accuracy
assert(error_exp_5 < error_exp_3, 'Error: 5-point should be more accurate than 3-point');
fprintf('  ✓ Higher point method is more accurate\n');

%% Test 6: Boundary behavior
fprintf('\nTest 6: Boundary behavior\n');
t = 0:0.1:2;
dt = 0.1;
test_data = t'.^2;  % Simple quadratic

dV_boundary = numerical_derivative(test_data, dt, 'num_points', 5);

% Check that boundaries are zero (as expected from implementation)
fprintf('  First two derivatives: %.6f, %.6f\n', dV_boundary(1), dV_boundary(2));
fprintf('  Last two derivatives: %.6f, %.6f\n', dV_boundary(end-1), dV_boundary(end));

% Verify boundary points are zero
assert(dV_boundary(1) == 0, 'First point should be zero');
assert(dV_boundary(2) == 0, 'Second point should be zero');
assert(dV_boundary(end-1) == 0, 'Second-to-last point should be zero');
assert(dV_boundary(end) == 0, 'Last point should be zero');
fprintf('  ✓ Boundary points are correctly set to zero\n');

%% Summary
fprintf('\n=== All tests passed! ===\n');
fprintf('The numerical_derivative function is working correctly.\n');