function test_polyorder_library()
    % TEST_POLYORDER_LIBRARY Comprehensive tests for the polyorder_library function.
    %
    % This function runs comprehensive test cases to verify that the polyorder_library
    % function correctly generates polynomial libraries with and without cross terms,
    % handles edge cases, and produces expected outputs for various input scenarios.
    % All expected values are calculated analytically using mathematical operations
    % to ensure complete test independence.

    fprintf('Running comprehensive tests for polyorder_library function...\n\n');
    
    %% Test 1: Basic 2D quadratic polynomial with cross terms
    fprintf('Test 1: Basic 2D quadratic polynomial with cross terms\n');
    xdat1 = [2 3; 4 5]; % 2x2 matrix with simple values
    polyorder1 = 2;
    [Theta1, column_names1] = polyorder_library(xdat1, polyorder1);
    
    % Calculate expected values analytically:
    % For 2D quadratic with cross terms: [1, x1, x2, x1^2, x1*x2, x2^2]
    % Row 1: x1=2, x2=3 -> [1, 2, 3, 2^2, 2*3, 3^2] = [1, 2, 3, 4, 6, 9]
    % Row 2: x1=4, x2=5 -> [1, 4, 5, 4^2, 4*5, 5^2] = [1, 4, 5, 16, 20, 25]
    x1_vals = xdat1(:, 1); % [2; 4]
    x2_vals = xdat1(:, 2); % [3; 5]
    
    expected_Theta1 = [ones(size(x1_vals)), x1_vals, x2_vals, x1_vals.^2, x1_vals.*x2_vals, x2_vals.^2];
    expected_names1 = {'1', 'x_1', 'x_2', 'x_1^2', 'x_1*x_2', 'x_2^2'};
    
    assert(isequal(size(Theta1), size(expected_Theta1)), 'Test 1 failed: Matrix size mismatch');
    assert(max(abs(Theta1(:) - expected_Theta1(:))) < 1e-10, 'Test 1 failed: Theta matrix values incorrect');
    assert(isequal(column_names1, expected_names1), 'Test 1 failed: Column names incorrect');
    assert(size(Theta1, 1) == 2 && size(Theta1, 2) == 6, 'Test 1 failed: Matrix size should be 2x6');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat1), size(Theta1));
    
    %% Test 2: Pure powers only (no cross terms)
    fprintf('\nTest 2: Pure powers only (use_cross_terms = false)\n');
    xdat2 = [1 2; 3 4]; % 2x2 matrix
    polyorder2 = 3;
    [Theta2, column_names2] = polyorder_library(xdat2, polyorder2, 'use_cross_terms', false);
    
    % Calculate expected values analytically:
    % Pure powers: [1, x1, x2, x1^2, x2^2, x1^3, x2^3]
    % Row 1: x1=1, x2=2 -> [1, 1, 2, 1^2, 2^2, 1^3, 2^3] = [1, 1, 2, 1, 4, 1, 8]
    % Row 2: x1=3, x2=4 -> [1, 3, 4, 3^2, 4^2, 3^3, 4^3] = [1, 3, 4, 9, 16, 27, 64]
    x1_vals = xdat2(:, 1); % [1; 3]
    x2_vals = xdat2(:, 2); % [2; 4]
    
    expected_Theta2 = [ones(size(x1_vals)), x1_vals, x2_vals, x1_vals.^2, x2_vals.^2, x1_vals.^3, x2_vals.^3];
    expected_names2 = {'1', 'x_1', 'x_2', 'x_1^2', 'x_2^2', 'x_1^3', 'x_2^3'};
    
    assert(isequal(size(Theta2), size(expected_Theta2)), 'Test 2 failed: Matrix size mismatch');
    assert(max(abs(Theta2(:) - expected_Theta2(:))) < 1e-10, 'Test 2 failed: Theta matrix values incorrect');
    assert(isequal(column_names2, expected_names2), 'Test 2 failed: Column names incorrect');
    assert(size(Theta2, 1) == 2 && size(Theta2, 2) == 7, 'Test 2 failed: Matrix size should be 2x7');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat2), size(Theta2));
    
    %% Test 3: 3D quadratic polynomial with cross terms
    fprintf('\nTest 3: 3D quadratic polynomial with cross terms\n');
    xdat3 = [1 2 1; 2 1 3]; % 2x3 matrix
    polyorder3 = 2;
    [Theta3, column_names3] = polyorder_library(xdat3, polyorder3, 'use_cross_terms', true);
    
    % Calculate expected values analytically:
    % 3D quadratic: [1, x1, x2, x3, x1^2, x1*x2, x1*x3, x2^2, x2*x3, x3^2]
    % Row 1: x1=1, x2=2, x3=1 -> [1, 1, 2, 1, 1, 2, 1, 4, 2, 1]
    % Row 2: x1=2, x2=1, x3=3 -> [1, 2, 1, 3, 4, 2, 6, 1, 3, 9]
    x1_vals = xdat3(:, 1); % [1; 2]
    x2_vals = xdat3(:, 2); % [2; 1]
    x3_vals = xdat3(:, 3); % [1; 3]
    
    expected_Theta3 = [ones(size(x1_vals)), x1_vals, x2_vals, x3_vals, ...
                       x1_vals.^2, x1_vals.*x2_vals, x1_vals.*x3_vals, ...
                       x2_vals.^2, x2_vals.*x3_vals, x3_vals.^2];
    expected_names3 = {'1', 'x_1', 'x_2', 'x_3', 'x_1^2', 'x_1*x_2', 'x_1*x_3', 'x_2^2', 'x_2*x_3', 'x_3^2'};
    
    assert(isequal(size(Theta3), size(expected_Theta3)), 'Test 3 failed: Matrix size mismatch');
    assert(max(abs(Theta3(:) - expected_Theta3(:))) < 1e-10, 'Test 3 failed: Theta matrix values incorrect');
    assert(isequal(column_names3, expected_names3), 'Test 3 failed: Column names incorrect');
    assert(size(Theta3, 1) == 2 && size(Theta3, 2) == 10, 'Test 3 failed: Matrix size should be 2x10');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat3), size(Theta3));
    
    %% Test 4: 2D cubic polynomial with all cross terms
    fprintf('\nTest 4: 2D cubic polynomial with all cross terms\n');
    xdat4 = [2 1]; % 1x2 matrix (single data point for simplicity)
    polyorder4 = 3;
    [Theta4, column_names4] = polyorder_library(xdat4, polyorder4, 'use_cross_terms', true);
    
    % Calculate expected values analytically:
    % 2D cubic: [1, x1, x2, x1^2, x1*x2, x2^2, x1^3, x1^2*x2, x1*x2^2, x2^3]
    % For x1=2, x2=1: [1, 2, 1, 4, 2, 1, 8, 4, 2, 1]
    x1 = 2;
    x2 = 1;
    
    expected_Theta4 = [1, x1, x2, x1^2, x1*x2, x2^2, x1^3, x1^2*x2, x1*x2^2, x2^3];
    expected_names4 = {'1', 'x_1', 'x_2', 'x_1^2', 'x_1*x_2', 'x_2^2', 'x_1^3', 'x_1^2*x_2', 'x_1*x_2^2', 'x_2^3'};
    
    assert(isequal(size(Theta4), size(expected_Theta4)), 'Test 4 failed: Matrix size mismatch');
    assert(max(abs(Theta4(:) - expected_Theta4(:))) < 1e-10, 'Test 4 failed: Theta matrix values incorrect');
    assert(isequal(column_names4, expected_names4), 'Test 4 failed: Column names incorrect');
    assert(size(Theta4, 1) == 1 && size(Theta4, 2) == 10, 'Test 4 failed: Matrix size should be 1x10');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat4), size(Theta4));
    
    %% Test 5: Linear polynomial (order 1)
    fprintf('\nTest 5: Linear polynomial (order 1)\n');
    xdat5 = [3 4 5; 6 7 8]; % 2x3 matrix
    polyorder5 = 1;
    [Theta5, column_names5] = polyorder_library(xdat5, polyorder5);
    
    % Calculate expected values analytically:
    % Linear: [1, x1, x2, x3]
    % Row 1: [1, 3, 4, 5]
    % Row 2: [1, 6, 7, 8]
    x1_vals = xdat5(:, 1); % [3; 6]
    x2_vals = xdat5(:, 2); % [4; 7]
    x3_vals = xdat5(:, 3); % [5; 8]
    
    expected_Theta5 = [ones(size(x1_vals)), x1_vals, x2_vals, x3_vals];
    expected_names5 = {'1', 'x_1', 'x_2', 'x_3'};
    
    assert(isequal(size(Theta5), size(expected_Theta5)), 'Test 5 failed: Matrix size mismatch');
    assert(max(abs(Theta5(:) - expected_Theta5(:))) < 1e-10, 'Test 5 failed: Theta matrix values incorrect');
    assert(isequal(column_names5, expected_names5), 'Test 5 failed: Column names incorrect');
    assert(size(Theta5, 1) == 2 && size(Theta5, 2) == 4, 'Test 5 failed: Matrix size should be 2x4');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat5), size(Theta5));
    
    %% Test 6: Single variable polynomial (1D case)
    fprintf('\nTest 6: Single variable polynomial (1D case)\n');
    xdat6 = [2; 3; 4]; % 3x1 matrix
    polyorder6 = 4;
    [Theta6, column_names6] = polyorder_library(xdat6, polyorder6);
    
    % Calculate expected values analytically:
    % 1D quartic: [1, x1, x1^2, x1^3, x1^4]
    % Row 1: x1=2 -> [1, 2, 4, 8, 16]
    % Row 2: x1=3 -> [1, 3, 9, 27, 81]
    % Row 3: x1=4 -> [1, 4, 16, 64, 256]
    x1_vals = xdat6(:, 1); % [2; 3; 4]
    
    expected_Theta6 = [ones(size(x1_vals)), x1_vals, x1_vals.^2, x1_vals.^3, x1_vals.^4];
    expected_names6 = {'1', 'x_1', 'x_1^2', 'x_1^3', 'x_1^4'};
    
    assert(isequal(size(Theta6), size(expected_Theta6)), 'Test 6 failed: Matrix size mismatch');
    assert(max(abs(Theta6(:) - expected_Theta6(:))) < 1e-10, 'Test 6 failed: Theta matrix values incorrect');
    assert(isequal(column_names6, expected_names6), 'Test 6 failed: Column names incorrect');
    assert(size(Theta6, 1) == 3 && size(Theta6, 2) == 5, 'Test 6 failed: Matrix size should be 3x5');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat6), size(Theta6));
    
    %% Test 7: Cross terms vs pure powers feature count verification
    fprintf('\nTest 7: Cross terms vs pure powers feature count verification\n');
    xdat7 = [1 2 3]; % 1x3 matrix (single row for simplicity)
    polyorder7 = 2;
    
    [Theta7_cross, names7_cross] = polyorder_library(xdat7, polyorder7, 'use_cross_terms', true);
    [Theta7_pure, names7_pure] = polyorder_library(xdat7, polyorder7, 'use_cross_terms', false);
    
    % Analytical feature count calculation:
    % 3D quadratic with cross terms: 1 + 3 + 6 = 10 terms
    % (constant + 3 linear + 3 pure squares + 3 cross products)
    % 3D quadratic pure powers: 1 + 3 + 3 = 7 terms
    % (constant + 3 linear + 3 pure squares)
    
    expected_cross_features = 10;
    expected_pure_features = 7;
    
    assert(size(Theta7_cross, 2) == expected_cross_features, 'Test 7 failed: Cross terms should have %d features', expected_cross_features);
    assert(size(Theta7_pure, 2) == expected_pure_features, 'Test 7 failed: Pure powers should have %d features', expected_pure_features);
    assert(length(names7_cross) == expected_cross_features, 'Test 7 failed: Cross terms names count incorrect');
    assert(length(names7_pure) == expected_pure_features, 'Test 7 failed: Pure powers names count incorrect');
    
    % First 4 columns should be identical (constant and linear terms)
    assert(isequal(Theta7_cross(:, 1:4), Theta7_pure(:, 1:4)), 'Test 7 failed: First 4 columns should be identical');
    
    fprintf('  Cross terms: %d features, Pure powers: %d features - PASSED\n', ...
        size(Theta7_cross, 2), size(Theta7_pure, 2));
    
    %% Test 8: Mathematical identity verification
    fprintf('\nTest 8: Mathematical identity verification\n');
    
    % Use special values that allow easy verification of polynomial identities
    xdat8 = [0 1; 1 0; 1 1; -1 1]; % 4x2 matrix with special values
    polyorder8 = 2;
    [Theta8, ~] = polyorder_library(xdat8, polyorder8);
    
    % Calculate expected values analytically using mathematical identities:
    % Row 1: x1=0, x2=1 -> [1, 0, 1, 0, 0, 1]
    % Row 2: x1=1, x2=0 -> [1, 1, 0, 1, 0, 0]
    % Row 3: x1=1, x2=1 -> [1, 1, 1, 1, 1, 1]
    % Row 4: x1=-1, x2=1 -> [1, -1, 1, 1, -1, 1]
    
    expected_Theta8 = [1  0  1  0   0  1;   % Row 1
                       1  1  0  1   0  0;   % Row 2
                       1  1  1  1   1  1;   % Row 3
                       1 -1  1  1  -1  1];  % Row 4
    
    assert(isequal(size(Theta8), size(expected_Theta8)), 'Test 8 failed: Matrix size mismatch');
    assert(max(abs(Theta8(:) - expected_Theta8(:))) < 1e-10, 'Test 8 failed: Mathematical identity verification failed');
    
    % Verify specific mathematical properties
    assert(Theta8(1, 2) == 0, 'Test 8 failed: 0^1 should equal 0');
    assert(Theta8(3, 5) == 1, 'Test 8 failed: 1*1 should equal 1');
    assert(Theta8(4, 2) == -1, 'Test 8 failed: (-1)^1 should equal -1');
    assert(Theta8(4, 4) == 1, 'Test 8 failed: (-1)^2 should equal 1');
    
    fprintf('  Mathematical identity verification - PASSED\n');
    
    %% Test 9: Large dimension scaling test
    fprintf('\nTest 9: Large dimension scaling test\n');
    xdat9 = rand(5, 4); % 5x4 matrix
    polyorder9 = 2;
    
    [Theta9_cross, ~] = polyorder_library(xdat9, polyorder9, 'use_cross_terms', true);
    [Theta9_pure, ~] = polyorder_library(xdat9, polyorder9, 'use_cross_terms', false);
    
    % For 4D quadratic:
    % Cross terms: 1 + 4 + 4 + C(4,2) = 1 + 4 + 4 + 6 = 15 columns
    % Pure powers: 1 + 4 + 4 = 9 columns
    
    assert(size(Theta9_cross, 2) == 15, 'Test 9 failed: 4D quadratic with cross terms should have 15 columns');
    assert(size(Theta9_pure, 2) == 9, 'Test 9 failed: 4D quadratic pure powers should have 9 columns');
    assert(size(Theta9_cross, 1) == 5 && size(Theta9_pure, 1) == 5, 'Test 9 failed: Should preserve number of rows');
    fprintf('  4D quadratic - Cross terms: %d columns, Pure powers: %d columns - PASSED\n', ...
        size(Theta9_cross, 2), size(Theta9_pure, 2));
    
    %% Test 10: Column name formatting verification
    fprintf('\nTest 10: Column name formatting verification\n');
    xdat10 = [1 2 3]; % 1x3 matrix
    polyorder10 = 2;
    [~, column_names10] = polyorder_library(xdat10, polyorder10, 'use_cross_terms', true);
    
    % Expected names for 3D quadratic with cross terms:
    expected_names10 = {'1', 'x_1', 'x_2', 'x_3', 'x_1^2', 'x_1*x_2', 'x_1*x_3', 'x_2^2', 'x_2*x_3', 'x_3^2'};
    
    assert(isequal(column_names10, expected_names10), 'Test 10 failed: Column names format incorrect');
    
    % Verify specific formatting rules
    assert(strcmp(column_names10{1}, '1'), 'Test 10 failed: Constant term should be "1"');
    assert(strcmp(column_names10{2}, 'x_1'), 'Test 10 failed: Linear term should be "x_1"');
    assert(strcmp(column_names10{5}, 'x_1^2'), 'Test 10 failed: Square term should be "x_1^2"');
    assert(strcmp(column_names10{6}, 'x_1*x_2'), 'Test 10 failed: Cross term should be "x_1*x_2"');
    
    fprintf('  Column name formatting verified - PASSED\n');
    
    %% Test 11: Numerical precision with fractional values
    fprintf('\nTest 11: Numerical precision with fractional values\n');
    
    % Use rational fractions that have exact decimal representations
    xdat11 = [0.5 0.25; 0.75 0.125]; % 2x2 matrix with exact fractions
    polyorder11 = 2;
    [Theta11, ~] = polyorder_library(xdat11, polyorder11);
    
    % Calculate expected values analytically:
    % Row 1: x1=0.5, x2=0.25 -> [1, 0.5, 0.25, 0.25, 0.125, 0.0625]
    % Row 2: x1=0.75, x2=0.125 -> [1, 0.75, 0.125, 0.5625, 0.09375, 0.015625]
    
    expected_Theta11 = [1    0.5     0.25    0.25      0.125     0.0625;
                        1    0.75    0.125   0.5625    0.09375   0.015625];
    
    assert(isequal(size(Theta11), size(expected_Theta11)), 'Test 11 failed: Matrix size mismatch');
    assert(max(abs(Theta11(:) - expected_Theta11(:))) < 1e-15, 'Test 11 failed: Numerical precision issue');
    
    % Verify specific calculations
    assert(abs(Theta11(1, 4) - 0.5^2) < 1e-15, 'Test 11 failed: 0.5^2 calculation incorrect');
    assert(abs(Theta11(1, 5) - 0.5*0.25) < 1e-15, 'Test 11 failed: 0.5*0.25 calculation incorrect');
    assert(abs(Theta11(2, 6) - 0.125^2) < 1e-15, 'Test 11 failed: 0.125^2 calculation incorrect');
    
    fprintf('  Numerical precision with fractions verified - PASSED\n');
    
    %% Test 12: Cross product mathematical properties
    fprintf('\nTest 12: Cross product mathematical properties\n');
    
    % Use values that allow verification of cross product properties
    xdat12 = [2 3; 0 5; 1 0]; % 3x2 matrix with strategic values
    polyorder12 = 2;
    [Theta12, ~] = polyorder_library(xdat12, polyorder12);
    
    % Verify cross product calculations analytically:
    % Row 1: x1=2, x2=3 -> x1*x2 = 2*3 = 6
    % Row 2: x1=0, x2=5 -> x1*x2 = 0*5 = 0
    % Row 3: x1=1, x2=0 -> x1*x2 = 1*0 = 0
    
    cross_product_column = 5; % x1*x2 should be 5th column in [1, x1, x2, x1^2, x1*x2, x2^2]
    expected_cross_products = [6; 0; 0];
    
    assert(isequal(Theta12(:, cross_product_column), expected_cross_products), ...
        'Test 12 failed: Cross product calculations incorrect');
    
    % Verify multiplication by zero property
    assert(Theta12(2, cross_product_column) == 0, 'Test 12 failed: 0*5 should equal 0');
    assert(Theta12(3, cross_product_column) == 0, 'Test 12 failed: 1*0 should equal 0');
    
    fprintf('  Cross product mathematical properties verified - PASSED\n');
    
    %% Test 13: Feature counting formula verification
    fprintf('\nTest 13: Feature counting formula verification\n');
    
    % Test systematic feature count using analytical formulas
    test_cases = [
        % [d, polyorder, use_cross_terms, expected_features]
        [1, 1, true,  2];   % 1D linear: 1 + 1 = 2
        [1, 2, true,  3];   % 1D quadratic: 1 + 1 + 1 = 3
        [1, 3, true,  4];   % 1D cubic: 1 + 1 + 1 + 1 = 4
        [2, 1, true,  3];   % 2D linear: 1 + 2 = 3
        [2, 2, true,  6];   % 2D quadratic: 1 + 2 + 3 = 6
        [2, 3, true, 10];   % 2D cubic: 1 + 2 + 3 + 4 = 10
        [3, 1, true,  4];   % 3D linear: 1 + 3 = 4
        [3, 2, true, 10];   % 3D quadratic: 1 + 3 + 6 = 10
        [2, 2, false, 5];   % 2D quadratic pure: 1 + 2 + 2 = 5
        [3, 2, false, 7];   % 3D quadratic pure: 1 + 3 + 3 = 7
        [4, 2, false, 9];   % 4D quadratic pure: 1 + 4 + 4 = 9
        [1, 4, false, 5];   % 1D quartic pure: 1 + 1 + 1 + 1 + 1 = 5
    ];
    
    for i = 1:size(test_cases, 1)
        d = test_cases(i, 1);
        polyorder = test_cases(i, 2);
        use_cross_terms = logical(test_cases(i, 3));
        expected_features = test_cases(i, 4);
        
        % Generate test data
        test_data = ones(5, d); % Use ones for simplicity
        [Theta_test, names_test] = polyorder_library(test_data, polyorder, 'use_cross_terms', use_cross_terms);
        actual_features = size(Theta_test, 2);
        
        assert(actual_features == expected_features, ...
            'Test 13 failed: Case %d (d=%d, order=%d, cross=%d) - expected %d features, got %d', ...
            i, d, polyorder, use_cross_terms, expected_features, actual_features);
        assert(length(names_test) == expected_features, ...
            'Test 13 failed: Case %d - column names count mismatch', i);
    end
    
    fprintf('  Feature count formulas verified for %d test cases - PASSED\n', size(test_cases, 1));
    
    %% Test 14: Error handling
    fprintf('\nTest 14: Error handling\n');
    
    % Test invalid polynomial order
    try
        polyorder_library([1 2; 3 4], 0); % polyorder = 0 should fail
        error('Test 14 failed: Should have thrown error for polyorder = 0');
    catch ME
        if contains(ME.message, 'mustBePositive') || contains(ME.message, 'positive')
            fprintf('  Correctly rejected polyorder = 0 - PASSED\n');
        else
            error('Test 14 failed: Wrong error message for polyorder = 0: %s', ME.message);
        end
    end
    
    % Test empty input
    try
        polyorder_library([], 2); % Empty input should fail
        error('Test 14 failed: Should have thrown error for empty input');
    catch ME
        if contains(ME.message, 'mustBeNonempty') || contains(ME.message, 'empty')
            fprintf('  Correctly rejected empty input - PASSED\n');
        else
            error('Test 14 failed: Wrong error message for empty input: %s', ME.message);
        end
    end
    
    %% Summary
    fprintf('\n=== ALL TESTS PASSED ===\n');
    fprintf('The polyorder_library function works correctly with analytical verification!\n');
    fprintf('Verified comprehensively:\n');
    fprintf('  - Basic polynomial library generation with cross terms\n');
    fprintf('  - Pure powers mode (use_cross_terms = false)\n');
    fprintf('  - Higher-order polynomials and multi-dimensional cases\n');
    fprintf('  - Mathematical identities and special value properties\n');
    fprintf('  - Cross terms vs pure powers feature counting\n');
    fprintf('  - Column name formatting and indexing\n');
    fprintf('  - Numerical precision with exact fractional calculations\n');
    fprintf('  - Cross product mathematical properties\n');
    fprintf('  - Feature count formulas derived from combinatorial analysis\n');
    fprintf('  - Large dimension scaling behavior\n');
    fprintf('  - Error handling for invalid inputs\n');
    fprintf('  - Edge cases with analytical expectations\n');
    fprintf('  - Complete independence from function implementation\n');
end
