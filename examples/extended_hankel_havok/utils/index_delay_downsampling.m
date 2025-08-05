function filtered_data = index_delay_downsampling(timeseries, options)
    % INDEX_DELAY_DOWNSAMPLING Downsamples a multidimensional time series by subsampling.
    %
    % This function takes a multidimensional time series and returns a downsampled
    % version by keeping every index_delay-th point, effectively reducing
    % the data while preserving the temporal structure.
    %
    % INPUTS:
    %   timeseries - Input time series data (N x d matrix) where:
    %                N is the number of time points
    %                d is the dimension of each point
    %   options.index_delay - Sampling interval (default: 1, positive integer)
    %                         1 = keep all points (no downsampling)
    %                         2 = keep every 2nd point (half the data)
    %                         3 = keep every 3rd point (one-third the data)
    %                         etc.
    %
    % OUTPUTS:
    %   filtered_data - Downsampled time series (floor((N-1)/index_delay)+1 x d matrix)
    %                   Contains every index_delay-th point from the original series
    %
    % EXAMPLE:
    %   % Create a 3D time series with 10 points
    %   timeseries = [1 10 100;   % Point 1
    %                 2 20 200;   % Point 2
    %                 3 30 300;   % Point 3
    %                 4 40 400;   % Point 4
    %                 5 50 500;   % Point 5
    %                 6 60 600;   % Point 6
    %                 7 70 700;   % Point 7
    %                 8 80 800;   % Point 8
    %                 9 90 900;   % Point 9
    %                10 100 1000; % Point 10
    %                11 110 1100]; % Point 11
    %
    %   % Filter with index_delay = 3 (keep every 3rd point)
    %   filtered = index_delay_downsampling(timeseries, "index_delay", 3);
    %   % Result: filtered = [1 10 100;    % Original point 1
    %   %                    4 40 400;    % Original point 4
    %   %                    7 70 700;    % Original point 7
    %   %                   10 100 1000]; % Original point 10
    %   % Size: 4 x 3 (floor((11-1)/3)+1 = 4 points)
    %
    % NOTES:
    %   - The function preserves the first point and then samples every index_delay-th point
    %   - Useful for reducing computational complexity in time-delay embedding
    %   - Commonly used in conjunction with Hankel matrix construction
    %   - The number of output points is floor((N-1)/index_delay)+1

    arguments
        timeseries (:,:) double {mustBeNonempty}
        options.index_delay (1,1) int32 {mustBeInteger, mustBePositive} = 1
    end
    
    [N, d] = size(timeseries);
    
    % Calculate the number of points in the filtered series
    % We always include the first point, then take every index_delay-th point
    delay = double(options.index_delay);
    num_filtered_points = floor((N - 1) / delay) + 1;
    
    % Check if we have at least one point after filtering
    if num_filtered_points < 1
        error('index_delay (%d) is too large for the given time series length (%d).', delay, N);
    end
    
    % Pre-allocate the filtered data matrix
    filtered_data = zeros(num_filtered_points, d);
    
    % Extract every index_delay-th point
    for i = 1:num_filtered_points
        idx = (i - 1) * delay + 1;
        filtered_data(i, :) = timeseries(idx, :);
    end
end