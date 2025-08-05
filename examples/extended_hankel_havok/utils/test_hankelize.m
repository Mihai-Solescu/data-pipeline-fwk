function test_hankelize()
    % TEST_HANKELIZE Tests the hankelize function.
    %
    % This function runs various test cases to verify that the hankelize
    % function correctly creates Hankel matrices with constant skew-diagonals
    % for time-delay embedding applications.

    fprintf('Running tests for hankelize function...\n\n');
    
    %% Test 1: Example 1 from documentation - Basic Hankel matrix (τ=1)
    fprintf('Test 1: Example 1 - Basic Hankel matrix (τ=1)\n');
    timeseries1 = [1; 2; 3; 4; 5; 6];
    result1 = hankelize(timeseries1, 3);
    expected1 = [1 2 3 4;    % x_0, x_0+1, x_0+2, x_0+3
                 2 3 4 5;    % x_0+1, x_0+2, x_0+3, x_0+4
                 3 4 5 6];   % x_0+2, x_0+3, x_0+4, x_0+5
    
    assert(isequal(result1, expected1), 'Test 1 failed: Basic Hankel matrix incorrect');
    assert(isequal(size(result1), [3 4]), 'Test 1 failed: Size should be 3x4');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries1), size(result1));
    
    %% Test 2: Example 2 from documentation - With time delay (τ=2)
    fprintf('\nTest 2: Example 2 - With time delay (τ=2)\n');
    timeseries2 = [1; 2; 3; 4; 5; 6; 7; 8];
    result2 = hankelize(timeseries2, 3, "index_delay", 2);
    expected2 = [1 3;        % x_0, x_0+2τ (τ=2)
                 3 5;        % x_0+τ, x_0+3τ  
                 5 7];       % x_0+2τ, x_0+4τ
    
    assert(isequal(result2, expected2), 'Test 2 failed: Time delay functionality incorrect');
    assert(isequal(size(result2), [3 2]), 'Test 2 failed: Size should be 3x2');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries2), size(result2));
    
    %% Test 3: Example 3 from documentation - Larger delay (τ=3)
    fprintf('\nTest 3: Example 3 - Larger delay (τ=3)\n');
    timeseries3 = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10];
    result3 = hankelize(timeseries3, 2, "index_delay", 3);
    expected3 = [1 4 7;      % x_0, x_0+3τ, x_0+6τ (τ=3)
                 4 7 10];    % x_0+τ, x_0+4τ, x_0+7τ
    
    assert(isequal(result3, expected3), 'Test 3 failed: Larger delay functionality incorrect');
    assert(isequal(size(result3), [2 3]), 'Test 3 failed: Size should be 2x3');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries3), size(result3));
    
    %% Test 4: Formula verification for various parameter combinations
    fprintf('\nTest 4: Formula verification\n');
    test_cases = [
        % [N, embedding_dim, delay, expected_rows, expected_cols]
        [6, 3, 1, 3, 4];    % Example 1
        [8, 3, 2, 3, 2];    % Example 2
        [10, 2, 3, 2, 3];   % Example 3
        [10, 4, 1, 4, 7];   % Different parameters
        [12, 2, 4, 2, 2];   % Larger delay
        [5, 2, 2, 2, 2];    % Small dataset
    ];
    
    for i = 1:size(test_cases, 1)
        N = test_cases(i, 1);
        embedding_dim = test_cases(i, 2);
        delay = test_cases(i, 3);
        expected_rows = test_cases(i, 4);
        expected_cols = test_cases(i, 5);
        
        % Create test data
        timeseries_test = (1:N)';
        
        % Test the function
        result_test = hankelize(timeseries_test, embedding_dim, "index_delay", delay);
        
        % Verify size
        actual_size = size(result_test);
        expected_size = [expected_rows, expected_cols];
        
        assert(isequal(actual_size, expected_size), ...
               sprintf('Formula verification failed for case %d: expected %dx%d, got %dx%d', ...
               i, expected_size(1), expected_size(2), actual_size(1), actual_size(2)));
        
        % Verify formula calculation
        calculated_cols = floor((N - (embedding_dim-1)*delay - 1) / delay) + 1;
        assert(calculated_cols == expected_cols, ...
               sprintf('Formula calculation failed for case %d: expected %d cols, calculated %d', ...
               i, expected_cols, calculated_cols));
    end
    fprintf('  Formula verified for %d different parameter combinations - PASSED\n', size(test_cases, 1));
    
    %% Test 5: Hankel matrix property - constant skew-diagonals
    fprintf('\nTest 5: Hankel matrix property verification\n');
    timeseries5 = [10; 20; 30; 40; 50; 60; 70; 80];
    result5 = hankelize(timeseries5, 3, "index_delay", 2);
    
    % Check skew-diagonal property
    % For τ=2, skew-diagonals should have values at positions differing by 2τ=4
    % Skew-diagonal 1: result5(1,1) = 10
    % Skew-diagonal 2: result5(1,2), result5(2,1) should both be 30
    % Skew-diagonal 3: result5(2,2), result5(3,1) should both be 50
    % etc.
    
    assert(result5(1,2) == result5(2,1), 'Test 5 failed: Skew-diagonal property violated');
    assert(result5(2,2) == result5(3,1), 'Test 5 failed: Skew-diagonal property violated');
    
    % Additional check: H(i,j) = timeseries((i-1)*τ + (j-1)*τ + 1)
    tau = 2;
    for i = 1:size(result5,1)
        for j = 1:size(result5,2)
            expected_val = timeseries5((i-1)*tau + (j-1)*tau + 1);
            assert(result5(i,j) == expected_val, ...
                   sprintf('Test 5 failed: H(%d,%d) should be %d but got %d', ...
                   i, j, expected_val, result5(i,j)));
        end
    end
    fprintf('  Hankel matrix skew-diagonal property verified - PASSED\n');
    
    %% Test 6: Edge case - Single embedding dimension
    fprintf('\nTest 6: Single embedding dimension\n');
    timeseries6 = [1; 2; 3; 4; 5];
    result6 = hankelize(timeseries6, 1, "index_delay", 2);
    expected6 = [1 3 5]; % Just one row with τ=2 spacing
    
    assert(isequal(result6, expected6), 'Test 6 failed: Single embedding dimension incorrect');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries6), size(result6));
    
    %% Test 7: Edge case - Large delay
    fprintf('\nTest 7: Large delay\n');
    timeseries7 = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10];
    result7 = hankelize(timeseries7, 2, "index_delay", 5);
    expected7 = [1; 6]; % Only one column possible with τ=5
    
    assert(isequal(result7, expected7), 'Test 7 failed: Large delay incorrect');
    assert(size(result7, 2) == 1, 'Test 7 failed: Should have only 1 column');
    fprintf('  Large delay handled correctly - PASSED\n');
    
    %% Test 8: Error handling - insufficient data
    fprintf('\nTest 8: Error handling\n');
    timeseries8 = [1; 2]; % Only 2 points
    try
        % This should error because we need more data
        result8 = hankelize(timeseries8, 3, "index_delay", 2);
        error('Test 8 failed: Should have thrown an error for insufficient data');
    catch ME
        if contains(ME.message, 'too short')
            fprintf('  Correctly detected insufficient data - PASSED\n');
        else
            error('Test 8 failed: Wrong error message: %s', ME.message);
        end
    end
    
    %% Test 9: Comparison with traditional Hankel (τ=1)
    fprintf('\nTest 9: Traditional Hankel matrix comparison\n');
    timeseries9 = [5; 10; 15; 20; 25; 30];
    result9 = hankelize(timeseries9, 3);
    
    % Traditional Hankel matrix should have H(i,j) = timeseries(i+j-1)
    % (for 1-based indexing)
    for i = 1:size(result9,1)
        for j = 1:size(result9,2)
            expected_val = timeseries9(i + j - 1);
            assert(result9(i,j) == expected_val, ...
                   sprintf('Test 9 failed: Traditional Hankel property violated at (%d,%d)', i, j));
        end
    end
    fprintf('  Traditional Hankel matrix property verified - PASSED\n');
    
    %% Test 10: Numerical stability with different data types
    fprintf('\nTest 10: Numerical data handling\n');
    timeseries10 = [1.1; 2.2; 3.3; 4.4; 5.5; 6.6; 7.7; 8.8];
    result10 = hankelize(timeseries10, 2, "index_delay", 3);
    expected10 = [1.1 4.4;   % x_0, x_0+3τ (τ=3)
                  4.4 7.7];  % x_0+τ, x_0+4τ
    
    assert(max(abs(result10(:) - expected10(:))) < 1e-10, ...
           'Test 10 failed: Numerical precision issue');
    fprintf('  Numerical data handled correctly - PASSED\n');
    
    %% Test 11: Verify indexing formula consistency
    fprintf('\nTest 11: Indexing formula consistency\n');
    timeseries11 = (1:20)';
    embedding_dim = 4;
    delay = 3;
    result11 = hankelize(timeseries11, embedding_dim, "index_delay", delay);
    
    % Verify that every element follows H(i,j) = timeseries((i-1)*τ + (j-1)*τ + 1)
    for i = 1:size(result11,1)
        for j = 1:size(result11,2)
            linear_idx = (i-1)*delay + (j-1)*delay + 1;
            expected_val = timeseries11(linear_idx);
            assert(result11(i,j) == expected_val, ...
                   sprintf('Test 11 failed: Indexing formula inconsistent at (%d,%d)', i, j));
        end
    end
    fprintf('  Indexing formula consistency verified - PASSED\n');
    
    %% Summary
    fprintf('\n=== ALL TESTS PASSED ===\n');
    fprintf('The hankelize function works correctly!\n');
    fprintf('Verified:\n');
    fprintf('  - Basic Hankel matrix construction (τ=1)\n');
    fprintf('  - Time-delayed Hankel matrices (τ>1)\n');
    fprintf('  - Constant skew-diagonal property\n');
    fprintf('  - Formula calculations for various parameters\n');
    fprintf('  - Edge cases and error handling\n');
    fprintf('  - Numerical precision\n');
    fprintf('  - Indexing formula consistency\n');
    fprintf('  - Traditional Hankel matrix compatibility\n');
end