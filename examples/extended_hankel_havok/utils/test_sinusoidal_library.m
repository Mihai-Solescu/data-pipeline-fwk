function test_sinusoidal_library()
    % TEST_SINUSOIDAL_LIBRARY Tests the sinusoidal_library function.
    %
    % This function runs comprehensive test cases to verify that the sinusoidal_library
    % function correctly generates sinusoidal libraries with sine and cosine terms,
    % handles different harmonics, variable subsets, and produces expected outputs
    % for various input scenarios.

    fprintf('Running tests for sinusoidal_library function...\n\n');
    
    %% Test 1: Basic 2D sinusoidal library with 1 harmonic (Example from documentation)
    fprintf('Test 1: Basic 2D sinusoidal library with 1 harmonic\n');
    xdat1 = [0 pi/2; pi/4 3*pi/4; pi/2 pi]; % 3x2 matrix
    max_harmonics1 = 1;
    [Theta1, column_names1] = sinusoidal_library(xdat1, 'nVars', 2, 'max_harmonics', max_harmonics1);
    
    % Expected: [sin(x_1), sin(x_2), cos(x_1), cos(x_2)]
    expected_Theta1 = [0      1      1      0;      % Row 1: [sin(0), sin(π/2), cos(0), cos(π/2)]
                       sqrt(2)/2 sqrt(2)/2 sqrt(2)/2 -sqrt(2)/2; % Row 2: [sin(π/4), sin(3π/4), cos(π/4), cos(3π/4)]
                       1      0      0     -1];     % Row 3: [sin(π/2), sin(π), cos(π/2), cos(π)]
    expected_names1 = {'sin(x_1)', 'sin(x_2)', 'cos(x_1)', 'cos(x_2)'};
    
    assert(isequal(size(Theta1), size(expected_Theta1)), 'Test 1 failed: Matrix size mismatch');
    assert(max(abs(Theta1(:) - expected_Theta1(:))) < 1e-10, 'Test 1 failed: Theta matrix values incorrect');
    assert(isequal(column_names1, expected_names1), 'Test 1 failed: Column names incorrect');
    assert(size(Theta1, 1) == 3 && size(Theta1, 2) == 4, 'Test 1 failed: Matrix size should be 3x4');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat1), size(Theta1));
    
    %% Test 2: Known mathematical values verification
    fprintf('\nTest 2: Known mathematical values verification\n');
    % Use well-known trigonometric values for independent verification
    xdat2 = [0 pi/2; pi/6 pi/3]; % Values with known exact trigonometric results
    max_harmonics2 = 2;
    [Theta2, column_names2] = sinusoidal_library(xdat2, 'nVars', 2, 'max_harmonics', max_harmonics2);
    
    % Manually calculate expected values using mathematical identities (not function output)
    % Row 1: x1=0, x2=π/2
    % [sin(0), sin(π/2), cos(0), cos(π/2), sin(0), sin(π), cos(0), cos(π)]
    % = [0, 1, 1, 0, 0, 0, 1, -1]
    row1_expected = [0, 1, 1, 0, 0, 0, 1, -1];
    
    % Row 2: x1=π/6, x2=π/3  
    % [sin(π/6), sin(π/3), cos(π/6), cos(π/3), sin(π/3), sin(2π/3), cos(π/3), cos(2π/3)]
    % = [1/2, √3/2, √3/2, 1/2, √3/2, √3/2, 1/2, -1/2]
    row2_expected = [1/2, sqrt(3)/2, sqrt(3)/2, 1/2, sqrt(3)/2, sqrt(3)/2, 1/2, -1/2];
    
    expected_Theta2 = [row1_expected; row2_expected];
    expected_names2 = {'sin(x_1)', 'sin(x_2)', 'cos(x_1)', 'cos(x_2)', 'sin(2*x_1)', 'sin(2*x_2)', 'cos(2*x_1)', 'cos(2*x_2)'};
    
    assert(isequal(size(Theta2), size(expected_Theta2)), 'Test 2 failed: Matrix size mismatch');
    assert(max(abs(Theta2(:) - expected_Theta2(:))) < 1e-10, 'Test 2 failed: Mathematical values incorrect');
    assert(isequal(column_names2, expected_names2), 'Test 2 failed: Column names incorrect');
    assert(size(Theta2, 1) == 2 && size(Theta2, 2) == 8, 'Test 2 failed: Matrix size should be 2x8');
    fprintf('  Mathematical verification with known exact values - PASSED\n');
    
    %% Test 3: Subset of variables (3D data, use first 2 variables)
    fprintf('\nTest 3: Subset of variables (3D data, use first 2 variables)\n');
    xdat3 = [1 2 3; 4 5 6; 7 8 9]; % 3x3 matrix
    [Theta3, column_names3] = sinusoidal_library(xdat3, 'nVars', 2, 'max_harmonics', 1);
    
    % Should only use first 2 columns, ignore column 3
    % Calculate expected values analytically using trigonometric functions
    % Row 1: [sin(1), sin(2), cos(1), cos(2)]
    % Row 2: [sin(4), sin(5), cos(4), cos(5)]  
    % Row 3: [sin(7), sin(8), cos(7), cos(8)]
    expected_Theta3 = [sin(1)  sin(2)  cos(1)  cos(2);
                       sin(4)  sin(5)  cos(4)  cos(5);
                       sin(7)  sin(8)  cos(7)  cos(8)];
    expected_names3 = {'sin(x_1)', 'sin(x_2)', 'cos(x_1)', 'cos(x_2)'};
    
    assert(isequal(size(Theta3), size(expected_Theta3)), 'Test 3 failed: Matrix size mismatch');
    assert(max(abs(Theta3(:) - expected_Theta3(:))) < 1e-10, 'Test 3 failed: Theta matrix values incorrect');
    assert(isequal(column_names3, expected_names3), 'Test 3 failed: Column names incorrect');
    assert(size(Theta3, 1) == 3 && size(Theta3, 2) == 4, 'Test 3 failed: Matrix size should be 3x4');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat3), size(Theta3));
    
    %% Test 4: Single variable with multiple harmonics
    fprintf('\nTest 4: Single variable with multiple harmonics\n');
    xdat4 = [0; pi/6; pi/4; pi/3; pi/2]; % 5x1 matrix
    [Theta4, column_names4] = sinusoidal_library(xdat4, 'nVars', 1, 'max_harmonics', 3);
    
    % Expected: [sin(x_1), cos(x_1), sin(2*x_1), cos(2*x_1), sin(3*x_1), cos(3*x_1)]
    expected_Theta4 = [0      1      0        1        0        1;        % x = 0
                       1/2    sqrt(3)/2 sqrt(3)/2 1/2   1        0;        % x = π/6
                       sqrt(2)/2 sqrt(2)/2 1     0     sqrt(2)/2 -sqrt(2)/2; % x = π/4
                       sqrt(3)/2 1/2    sqrt(3)/2 -1/2  0       -1;        % x = π/3
                       1      0     0       -1       -1        0];        % x = π/2: sin(3π/2)=-1, cos(3π/2)=0
    expected_names4 = {'sin(x_1)', 'cos(x_1)', 'sin(2*x_1)', 'cos(2*x_1)', 'sin(3*x_1)', 'cos(3*x_1)'};
    
    assert(isequal(size(Theta4), size(expected_Theta4)), 'Test 4 failed: Matrix size mismatch');
    assert(max(abs(Theta4(:) - expected_Theta4(:))) < 1e-10, 'Test 4 failed: Theta matrix values incorrect');
    assert(isequal(column_names4, expected_names4), 'Test 4 failed: Column names incorrect');
    assert(size(Theta4, 1) == 5 && size(Theta4, 2) == 6, 'Test 4 failed: Matrix size should be 5x6');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', size(xdat4), size(Theta4));
    
    %% Test 5: Default parameters
    fprintf('\nTest 5: Default parameters\n');
    xdat5 = [1 2; 3 4]; % 2x2 matrix
    [Theta5, column_names5] = sinusoidal_library(xdat5); % Use all defaults
    
    % Should use all variables (2) and default max_harmonics (10)
    expected_num_terms = 2 * 2 * 10; % 40 terms
    assert(size(Theta5, 2) == expected_num_terms, 'Test 5 failed: Should have 40 columns with defaults');
    assert(size(Theta5, 1) == 2, 'Test 5 failed: Should preserve number of rows');
    assert(length(column_names5) == expected_num_terms, 'Test 5 failed: Should have 40 column names');
    fprintf('  Default parameters: %d harmonics, %d variables, %d terms - PASSED\n', 10, 2, expected_num_terms);
    
    %% Test 6: Column name formatting verification
    fprintf('\nTest 6: Column name formatting verification\n');
    xdat6 = [1 2; 3 4]; % 2x2 matrix
    [~, column_names6] = sinusoidal_library(xdat6, 'nVars', 2, 'max_harmonics', 3);
    
    % Verify specific name patterns for 3 harmonics
    expected_pattern = {'sin(x_1)', 'sin(x_2)', 'cos(x_1)', 'cos(x_2)', ...
                        'sin(2*x_1)', 'sin(2*x_2)', 'cos(2*x_1)', 'cos(2*x_2)', ...
                        'sin(3*x_1)', 'sin(3*x_2)', 'cos(3*x_1)', 'cos(3*x_2)'};
    
    assert(isequal(column_names6, expected_pattern), 'Test 6 failed: Column name pattern incorrect');
    
    % Check for correct harmonic numbering
    assert(any(strcmp(column_names6, 'sin(x_1)')), 'Test 6 failed: Should contain "sin(x_1)"');
    assert(any(strcmp(column_names6, 'sin(2*x_1)')), 'Test 6 failed: Should contain "sin(2*x_1)"');
    assert(any(strcmp(column_names6, 'cos(3*x_2)')), 'Test 6 failed: Should contain "cos(3*x_2)"');
    
    fprintf('  Column naming format verified - PASSED\n');
    
    %% Test 7: Feature count verification
    fprintf('\nTest 7: Feature count verification\n');
    
    % Test various combinations to verify feature count formula: 2 * nVars * max_harmonics
    test_cases = [
        % [nVars, max_harmonics, expected_features]
        [1, 1, 2];     % 2 * 1 * 1 = 2
        [2, 1, 4];     % 2 * 2 * 1 = 4
        [3, 2, 12];    % 2 * 3 * 2 = 12
        [2, 5, 20];    % 2 * 2 * 5 = 20
        [1, 10, 20];   % 2 * 1 * 10 = 20
        [4, 3, 24];    % 2 * 4 * 3 = 24
    ];
    
    for i = 1:size(test_cases, 1)
        nVars = test_cases(i, 1);
        max_harmonics = test_cases(i, 2);
        expected_features = test_cases(i, 3);
        
        test_data = rand(10, nVars);
        [Theta_test, ~] = sinusoidal_library(test_data, 'nVars', nVars, 'max_harmonics', max_harmonics);
        actual_features = size(Theta_test, 2);
        
        assert(actual_features == expected_features, ...
            'Test 7 failed: Case %d - expected %d features, got %d', ...
            i, expected_features, actual_features);
    end
    
    fprintf('  Feature count formulas verified for %d test cases - PASSED\n', size(test_cases, 1));
    
    %% Test 8: Numerical precision test
    fprintf('\nTest 8: Numerical precision test\n');
    xdat8 = [pi/2 pi; 0 pi/4]; % Known trigonometric values
    [Theta8, ~] = sinusoidal_library(xdat8, 'nVars', 2, 'max_harmonics', 1);
    
    % Verify specific calculations with high precision
    % Row 1: [sin(π/2), sin(π), cos(π/2), cos(π)] = [1, 0, 0, -1]
    expected_row1 = [1, 0, 0, -1];
    % Row 2: [sin(0), sin(π/4), cos(0), cos(π/4)] = [0, √2/2, 1, √2/2]
    expected_row2 = [0, sqrt(2)/2, 1, sqrt(2)/2];
    
    assert(max(abs(Theta8(1, :) - expected_row1)) < 1e-10, ...
        'Test 8 failed: First row precision issue');
    assert(max(abs(Theta8(2, :) - expected_row2)) < 1e-10, ...
        'Test 8 failed: Second row precision issue');
    
    fprintf('  Numerical precision verified - PASSED\n');
    
    %% Test 9: Automatic nVars limiting
    fprintf('\nTest 9: Automatic nVars limiting\n');
    xdat9 = [1 2; 3 4]; % 2x2 matrix
    [Theta9, column_names9] = sinusoidal_library(xdat9, 'nVars', 5, 'max_harmonics', 1); % Request 5 vars but only 2 available
    
    % Should automatically limit to 2 variables
    expected_features = 2 * 2 * 1; % 4 features
    assert(size(Theta9, 2) == expected_features, 'Test 9 failed: Should limit to available variables');
    assert(length(column_names9) == expected_features, 'Test 9 failed: Column names should match limited variables');
    
    fprintf('  Automatic nVars limiting verified - PASSED\n');
    
    %% Test 10: Large dimension scaling test
    fprintf('\nTest 10: Large dimension scaling test\n');
    xdat10 = rand(50, 5); % 50 observations of 5D system
    [Theta10, column_names10] = sinusoidal_library(xdat10, 'nVars', 5, 'max_harmonics', 4);
    
    % Expected: 2 * 5 * 4 = 40 features
    expected_features = 40;
    
    assert(size(Theta10, 2) == expected_features, 'Test 10 failed: Should have 40 features');
    assert(size(Theta10, 1) == 50, 'Test 10 failed: Should preserve number of observations');
    assert(length(column_names10) == expected_features, 'Test 10 failed: Should have 40 column names');
    
    fprintf('  5D system with 4 harmonics: %d features - PASSED\n', expected_features);
    
    %% Test 11: Edge case - single harmonic, single variable
    fprintf('\nTest 11: Edge case - single harmonic, single variable\n');
    xdat11 = [0; pi/2; pi]; % 3x1 matrix
    [Theta11, column_names11] = sinusoidal_library(xdat11, 'nVars', 1, 'max_harmonics', 1);
    
    % Expected: [sin(x_1), cos(x_1)]
    expected_Theta11 = [0 1; 1 0; 0 -1];
    expected_names11 = {'sin(x_1)', 'cos(x_1)'};
    
    assert(isequal(size(Theta11), [3, 2]), 'Test 11 failed: Matrix size should be 3x2');
    assert(max(abs(Theta11(:) - expected_Theta11(:))) < 1e-10, 'Test 11 failed: Values incorrect');
    assert(isequal(column_names11, expected_names11), 'Test 11 failed: Column names incorrect');
    
    fprintf('  Single variable, single harmonic case - PASSED\n');
    
    %% Test 12: Harmonic progression verification
    fprintf('\nTest 12: Harmonic progression verification\n');
    xdat12 = [1]; % Single value
    [Theta12, ~] = sinusoidal_library(xdat12, 'nVars', 1, 'max_harmonics', 4);
    
    % Check that harmonics are correctly applied
    % Expected values calculated analytically using trigonometric functions:
    % [sin(1), cos(1), sin(2), cos(2), sin(3), cos(3), sin(4), cos(4)]
    expected_values = [sin(1)  cos(1)  sin(2)  cos(2)  sin(3)  cos(3)  sin(4)  cos(4)];
    
    assert(size(Theta12, 2) == 8, 'Test 12 failed: Should have 8 features (4 harmonics * 2 functions)');
    assert(max(abs(Theta12(1,:) - expected_values)) < 1e-10, 'Test 12 failed: Harmonic values incorrect');
    
    fprintf('  Harmonic progression verified - PASSED\n');
    
    %% Test 13: Error handling
    fprintf('\nTest 13: Error handling\n');
    
    % Test empty input
    try
        sinusoidal_library([], 'nVars', 1, 'max_harmonics', 1); % Empty input should work but produce empty output
        empty_result = true;
    catch
        empty_result = false;
    end
    assert(empty_result, 'Test 13 failed: Should handle empty input gracefully');
    
    % Test zero harmonics (should produce empty library)
    [Theta_zero, names_zero] = sinusoidal_library([1 2; 3 4], 'nVars', 2, 'max_harmonics', 0);
    assert(isempty(Theta_zero), 'Test 13 failed: Zero harmonics should produce empty Theta');
    assert(isempty(names_zero), 'Test 13 failed: Zero harmonics should produce empty names');
    
    fprintf('  Error handling verified - PASSED\n');
    
    %% Summary
    fprintf('\n=== ALL TESTS PASSED ===\n');
    fprintf('The sinusoidal_library function works correctly!\n');
    fprintf('Verified:\n');
    fprintf('  - Basic sinusoidal library generation with sine and cosine terms\n');
    fprintf('  - Multiple harmonics handling\n');
    fprintf('  - Variable subset selection\n');
    fprintf('  - Default parameter behavior\n');
    fprintf('  - Column name formatting and indexing\n');
    fprintf('  - Numerical precision with known trigonometric values\n');
    fprintf('  - Feature count formulas for various scenarios\n');
    fprintf('  - Automatic variable limiting\n');
    fprintf('  - Scaling behavior for large dimensions\n');
    fprintf('  - Edge cases (single variable/harmonic)\n');
    fprintf('  - Harmonic progression correctness\n');
    fprintf('  - Error handling for edge inputs\n');
end
