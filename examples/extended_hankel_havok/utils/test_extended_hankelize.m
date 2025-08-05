function test_extended_hankelize()
    % TEST_EXTENDED_HANKELIZE Tests the extended_hankelize function.
    %
    % This function runs various test cases to verify that the extended_hankelize
    % function works correctly with different input scenarios.

    fprintf('Running tests for extended_hankelize function...\n\n');
    
    %% Test 1: Example 1 from documentation - Basic 2D time series with no delays
    fprintf('Test 1: Example 1 - Basic 2D time series (no delays)\n');
    timeseries1 = [1 10; 2 20; 3 30; 4 40; 5 50]; % 5x2 matrix
    result1 = extended_hankelize(timeseries1, 3);
    expected1 = [1 2 3;      % x_0, x_1, x_2
                 10 20 30;   % (first d=2 rows)
                 2 3 4;      % x_1, x_2, x_3  
                 20 30 40;   % (second d=2 rows)
                 3 4 5;      % x_2, x_3, x_4
                 30 40 50];  % (third d=2 rows)
    
    assert(isequal(result1, expected1), 'Test 1 failed: Basic functionality incorrect');
    assert(isequal(size(result1), [6 3]), 'Test 1 failed: Size should be 6x3');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries1), size(result1));
    
    %% Test 2: Example 2 from documentation - With column delay
    fprintf('\nTest 2: Example 2 - With column delay\n');
    timeseries2 = [1 10; 2 20; 3 30; 4 40; 5 50; 6 60]; % 6x2 matrix
    result2 = extended_hankelize(timeseries2, 2, "col_index_delay", 2);
    expected2 = [1 3 5;      % x_0, x_2, x_4
                 10 30 50;   % (first d=2 rows)
                 2 4 6;      % x_1, x_3, x_5
                 20 40 60];  % (second d=2 rows)
    
    assert(isequal(result2, expected2), 'Test 2 failed: Column delay functionality incorrect');
    assert(isequal(size(result2), [4 3]), 'Test 2 failed: Size should be 4x3');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries2), size(result2));
    
    %% Test 3: Example 3 from documentation - With row delay
    fprintf('\nTest 3: Example 3 - With row delay\n');
    timeseries3 = [1 10; 2 20; 3 30; 4 40; 5 50; 6 60]; % 6x2 matrix
    result3 = extended_hankelize(timeseries3, 2, "row_index_delay", 2);
    expected3 = [1 2 3 4;    % x_0, x_1, x_2, x_3
                 10 20 30 40; % (first d=2 rows)
                 3 4 5 6;    % x_2, x_3, x_4, x_5
                 30 40 50 60]; % (second d=2 rows)
    
    assert(isequal(result3, expected3), 'Test 3 failed: Row delay functionality incorrect');
    assert(isequal(size(result3), [4 4]), 'Test 3 failed: Size should be 4x4');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries3), size(result3));
    
    %% Test 4: Example 4 from documentation - With both row and column delays
    fprintf('\nTest 4: Example 4 - With both row and column delays\n');
    timeseries4 = [1 10; 2 20; 3 30; 4 40; 5 50; 6 60; 7 70; 8 80; 9 90; 10 100; 11 110; 12 120]; % 12x2 matrix
    result4 = extended_hankelize(timeseries4, 3, "row_index_delay", 3, "col_index_delay", 2);
    expected4 = [1 3 5;      % x_0, x_2, x_4 (1st, 3rd, 5th elements)
                 10 30 50;   % (first d=2 rows)
                 4 6 8;      % x_3, x_5, x_7 (4th, 6th, 8th elements)
                 40 60 80;   % (second d=2 rows)
                 7 9 11;     % x_6, x_8, x_10 (7th, 9th, 11th elements)
                 70 90 110]; % (third d=2 rows)
    
    assert(isequal(result4, expected4), 'Test 4 failed: Both delays functionality incorrect');
    assert(isequal(size(result4), [6 3]), 'Test 4 failed: Size should be 6x3');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries4), size(result4));
    
    %% Test 5: Formula verification for various parameter combinations
    fprintf('\nTest 5: Formula verification\n');
    test_cases = [
        % [N, d, embedding_dim_multiple, row_delay, col_delay, expected_rows, expected_cols]
        [5, 2, 3, 1, 1, 6, 3];   % Example 1
        [6, 2, 2, 1, 2, 4, 3];   % Example 2
        [6, 2, 2, 2, 1, 4, 4];   % Example 3
        [12, 2, 3, 3, 2, 6, 3];  % Example 4
        [10, 3, 2, 1, 1, 6, 9];  % Different dimensions
        [8, 1, 4, 1, 2, 4, 3];   % 1D time series
    ];
    
    for i = 1:size(test_cases, 1)
        N = test_cases(i, 1);
        d = test_cases(i, 2);
        embedding_dim_multiple = test_cases(i, 3);
        row_delay = test_cases(i, 4);
        col_delay = test_cases(i, 5);
        expected_rows = test_cases(i, 6);
        expected_cols = test_cases(i, 7);
        
        % Create test data
        timeseries_test = rand(N, d);
        
        % Test the function
        result_test = extended_hankelize(timeseries_test, embedding_dim_multiple, ...
                                        "row_index_delay", row_delay, "col_index_delay", col_delay);
        
        % Verify size
        actual_size = size(result_test);
        expected_size = [expected_rows, expected_cols];
        
        assert(isequal(actual_size, expected_size), ...
               'Formula verification failed for case %d: expected %dx%d, got %dx%d', ...
               i, expected_size, actual_size);
        
        % Verify formula calculation
        calculated_cols = floor((N - (embedding_dim_multiple-1)*row_delay - 1) / col_delay) + 1;
        assert(calculated_cols == expected_cols, ...
               'Formula calculation failed for case %d: expected %d cols, calculated %d', ...
               i, expected_cols, calculated_cols);
    end
    fprintf('  Formula verified for %d different parameter combinations - PASSED\n', size(test_cases, 1));
    
    %% Test 6: 1D time series
    fprintf('\nTest 6: 1D time series\n');
    timeseries6 = [1; 2; 3; 4; 5; 6; 7]; % 7x1 matrix
    result6 = extended_hankelize(timeseries6, 3, "col_index_delay", 2);
    expected6 = [1 3 5;  % x_0, x_2, x_4
                 2 4 6;  % x_1, x_3, x_5
                 3 5 7]; % x_2, x_4, x_6
    
    assert(isequal(result6, expected6), 'Test 6 failed: 1D time series incorrect');
    fprintf('  1D input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries6), size(result6));
    
    %% Test 7: Edge case - Single embedding dimension
    fprintf('\nTest 7: Single embedding dimension\n');
    timeseries7 = [1 10; 2 20; 3 30; 4 40];
    result7 = extended_hankelize(timeseries7, 1);
    expected7 = [1 2 3 4; 10 20 30 40]; % Just the original data transposed
    
    assert(isequal(result7, expected7), 'Test 7 failed: Single embedding dimension incorrect');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries7), size(result7));
    
    %% Test 8: Error handling - insufficient data
    fprintf('\nTest 8: Error handling\n');
    timeseries8 = [1 10; 2 20]; % Only 2 points
    try
        % This should error because we need more data
        result8 = extended_hankelize(timeseries8, 3, "row_index_delay", 2);
        error('Test 8 failed: Should have thrown an error for insufficient data');
    catch ME
        if contains(ME.message, 'too short')
            fprintf('  Correctly detected insufficient data - PASSED\n');
        else
            error('Test 8 failed: Wrong error message: %s', ME.message);
        end
    end
    
    %% Test 9: Verify Hankel structure property
    fprintf('\nTest 9: Hankel structure verification\n');
    timeseries9 = [1 100; 2 200; 3 300; 4 400; 5 500; 6 600];
    result9 = extended_hankelize(timeseries9, 2, "row_index_delay", 1, "col_index_delay", 1);
    
    % Verify anti-diagonal property (for same embedding, shifted columns should be consecutive)
    % H(1,2) should equal H(2,1) (both should be the same data point)
    % Since each point occupies d=2 rows, we check the pattern
    assert(result9(1,2) == result9(3,1), 'Test 9 failed: Hankel structure property violated');
    assert(result9(2,2) == result9(4,1), 'Test 9 failed: Hankel structure property violated');
    fprintf('  Hankel structure property verified - PASSED\n');
    
    %% Test 10: Large delays
    fprintf('\nTest 10: Large delays\n');
    timeseries10 = rand(20, 2);
    result10 = extended_hankelize(timeseries10, 2, "row_index_delay", 5, "col_index_delay", 3);
    
    % Should produce some valid result without error
    assert(size(result10, 1) == 4, 'Test 10 failed: Wrong number of rows');
    assert(size(result10, 2) > 0, 'Test 10 failed: Should produce at least one column');
    fprintf('  Large delays handled correctly - PASSED\n');
    
    %% Summary
    fprintf('\n=== ALL TESTS PASSED ===\n');
    fprintf('The extended_hankelize function works correctly!\n');
    fprintf('Verified:\n');
    fprintf('  - Basic functionality with no delays\n');
    fprintf('  - Column delay functionality\n');
    fprintf('  - Row delay functionality\n');
    fprintf('  - Combined row and column delays\n');
    fprintf('  - Formula calculations\n');
    fprintf('  - 1D time series support\n');
    fprintf('  - Edge cases and error handling\n');
    fprintf('  - Hankel matrix structure properties\n');
end
