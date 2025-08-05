function test_index_delay_downsampling()
    % TEST_INDEX_DELAY_DOWNSAMPLING Tests the index_delay_downsampling function.
    %
    % This function runs various test cases to verify that the index_delay_downsampling
    % function works correctly with different input scenarios.

    fprintf('Running tests for index_delay_downsampling function...\n\n');
    
    %% Test 1: Basic functionality with default delay (should keep all points)
    fprintf('Test 1: Default delay (index_delay = 1)\n');
    timeseries1 = [1 10; 2 20; 3 30; 4 40; 5 50];
    result1 = index_delay_downsampling(timeseries1);
    expected1 = timeseries1; % Should be the same
    
    assert(isequal(result1, expected1), 'Test 1 failed: Default delay should keep all points');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries1), size(result1));
    
    %% Test 2: Delay of 2 (keep every 2nd point)
    fprintf('\nTest 2: index_delay = 2\n');
    timeseries2 = [1 10 100; 2 20 200; 3 30 300; 4 40 400; 5 50 500; 6 60 600];
    result2 = index_delay_downsampling(timeseries2, "index_delay", 2);
    expected2 = [1 10 100; 3 30 300; 5 50 500]; % Points 1, 3, 5
    
    assert(isequal(result2, expected2), 'Test 2 failed: Delay=2 indexing incorrect');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries2), size(result2));
    fprintf('  Expected %d points, got %d points\n', size(expected2,1), size(result2,1));
    
    %% Test 3: Delay of 3 (example from documentation)
    fprintf('\nTest 3: index_delay = 3 (documentation example)\n');
    timeseries3 = [1 10 100; 2 20 200; 3 30 300; 4 40 400; 5 50 500; 
                   6 60 600; 7 70 700; 8 80 800; 9 90 900; 10 100 1000; 11 110 1100];
    result3 = index_delay_downsampling(timeseries3, "index_delay", 3);
    expected3 = [1 10 100; 4 40 400; 7 70 700; 10 100 1000]; % Points 1, 4, 7, 10
    
    assert(isequal(result3, expected3), 'Test 3 failed: Documentation example incorrect');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries3), size(result3));
    fprintf('  Formula check: floor((%d-1)/%d)+1 = %d points\n', ...
            size(timeseries3,1), 3, size(result3,1));
    
    %% Test 4: Large delay (should return only first point)
    fprintf('\nTest 4: Large delay (should return only first point)\n');
    timeseries4 = [1 2 3; 4 5 6; 7 8 9];
    result4 = index_delay_downsampling(timeseries4, "index_delay", 10);
    expected4 = [1 2 3]; % Only first point
    
    assert(isequal(result4, expected4), 'Test 4 failed: Large delay should return only first point');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries4), size(result4));
    
    %% Test 5: Single point input
    fprintf('\nTest 5: Single point input\n');
    timeseries5 = [42 84 126];
    result5 = index_delay_downsampling(timeseries5, "index_delay", 1);
    expected5 = [42 84 126];
    
    assert(isequal(result5, expected5), 'Test 5 failed: Single point should be preserved');
    fprintf('  Input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries5), size(result5));
    
    %% Test 6: Formula verification for various sizes
    fprintf('\nTest 6: Formula verification\n');
    for N = 5:10
        for delay = 1:3
            timeseries_test = rand(N, 2);
            result_test = index_delay_downsampling(timeseries_test, "index_delay", delay);
            expected_size = floor((N - 1) / delay) + 1;
            actual_size = size(result_test, 1);
            
            assert(actual_size == expected_size, ...
                   'Formula verification failed for N=%d, delay=%d', N, delay);
        end
    end
    fprintf('  Formula floor((N-1)/delay)+1 verified for N=5:10, delay=1:3 - PASSED\n');
    
    %% Test 7: Check that first point is always preserved
    fprintf('\nTest 7: First point preservation\n');
    timeseries7 = [99 88 77; 1 2 3; 4 5 6; 7 8 9; 10 11 12];
    for delay = 1:5
        result7 = index_delay_downsampling(timeseries7, "index_delay", delay);
        assert(isequal(result7(1,:), timeseries7(1,:)), ...
               'First point not preserved for delay=%d', delay);
    end
    fprintf('  First point preserved for all delays 1:5 - PASSED\n');
    
    %% Test 8: Error handling (delay too large)
    fprintf('\nTest 8: Error handling\n');
    timeseries8 = [1 2; 3 4];
    try
        % This should not error since floor((2-1)/2)+1 = 1
        result8 = index_delay_downsampling(timeseries8, "index_delay", 2);
        assert(size(result8,1) == 1, 'Should return exactly 1 point');
        fprintf('  Delay=2 with N=2 correctly handled (returns 1 point) - PASSED\n');
    catch ME
        error('Test 8 failed: Unexpected error for valid delay');
    end
    
    %% Test 9: 1D time series (column vector)
    fprintf('\nTest 9: 1D time series\n');
    timeseries9 = [1; 2; 3; 4; 5; 6; 7];
    result9 = index_delay_downsampling(timeseries9, "index_delay", 3);
    expected9 = [1; 4; 7]; % Points 1, 4, 7
    
    assert(isequal(result9, expected9), 'Test 9 failed: 1D time series incorrect');
    fprintf('  1D input size: %dx%d, Output size: %dx%d - PASSED\n', ...
            size(timeseries9), size(result9));
    
    %% Summary
    fprintf('\n=== ALL TESTS PASSED ===\n');
    fprintf('The index_delay_downsampling function works correctly!\n');
end
