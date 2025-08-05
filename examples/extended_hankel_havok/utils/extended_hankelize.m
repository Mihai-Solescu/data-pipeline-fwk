function H = extended_hankelize(timeseries, embedding_dim_multiple, options)
    % EXTENDED_HANKELIZE Creates a Hankel matrix from a multidimensional time series.
    %
    % This function creates a Hankel matrix from a multidimensional time series
    % where each data point is a d-dimensional vector. The Hankel matrix is
    % constructed by stacking time-delayed copies of the data points.
    %
    % INPUTS:
    %   timeseries           - Input time series data (N x d matrix) where:
    %                          N is the number of time points
    %                          d is the dimension of each point
    %   embedding_dim_multiple - Number of time-delayed copies to stack vertically
    %                          (positive integer). The resulting Hankel matrix
    %                          will have (embedding_dim_multiple * d) rows
    %   options.row_index_delay - Time delay between consecutive row blocks
    %                           (default: 1, positive integer)
    %   options.col_index_delay - Time delay between consecutive column blocks
    %                           (default: 1, positive integer)
    %
    % OUTPUTS:
    %   H - Hankel matrix of size ((embedding_dim_multiple * d) x num_cols) where:
    %       - Each column block contains d-dimensional data points
    %       - Each row block represents time-delayed copies
    %       - num_cols = floor((N - (embedding_dim_multiple-1)*row_index_delay - 1) / col_index_delay) + 1
    %
    % STRUCTURE:
    %   The Hankel matrix has the structure:
    %   H = [x_0         x_0+c       x_0+2c     ...  ]
    %       [x_0+r       x_0+r+c     x_0+r+2c   ...  ]
    %       [x_0+2r      x_0+2r+c    x_0+2r+2c  ...  ]
    %       [  ...         ...         ...      ...  ]
    %   
    %   where:
    %   - x_i represents the i-th data point (d-dimensional column vector)
    %   - r = row_index_delay (row delay)
    %   - c = col_index_delay (column delay)
    %   - Each x_i occupies d rows in the matrix
    %
    % EXAMPLE 1: Basic 2D time series with no delays
    %   timeseries = [1 10; 2 20; 3 30; 4 40; 5 50]; % 5x2 matrix
    %   H = extended_hankelize(timeseries, 3);
    %   % Result: H = [1 2 3;     % x_0, x_1, x_2
    %   %              10 20 30;  % (first d=2 rows)
    %   %              2 3 4;     % x_1, x_2, x_3  
    %   %              20 30 40;  % (second d=2 rows)
    %   %              3 4 5;     % x_2, x_3, x_4
    %   %              30 40 50]; % (third d=2 rows)
    %   % Size: (3*2) x 3 = 6 x 3
    %   % num_cols = floor((5 - (3-1)*1 - 1) / 1) + 1 = floor(2 / 1) + 1 = 2 + 1 = 3
    %
    % EXAMPLE 2: With column delay
    %   timeseries = [1 10; 2 20; 3 30; 4 40; 5 50; 6 60]; % 6x2 matrix
    %   H = extended_hankelize(timeseries, 2, "col_index_delay", 2);
    %   % Column blocks: x_0, x_2, x_4 (every 2nd point)
    %   % Result: H = [1 3 5;      % x_0, x_2, x_4
    %   %              10 30 50;   % (first d=2 rows)
    %   %              2 4 6;      % x_1, x_3, x_5
    %   %              20 40 60];  % (second d=2 rows)
    %   % Size: (2*2) x 3 = 4 x 3
    %   % num_cols = floor((6 - (2-1)*1 - 1) / 2) + 1 = floor(4 / 2) + 1 = 2 + 1 = 3
    %
    % EXAMPLE 3: With row delay
    %   timeseries = [1 10; 2 20; 3 30; 4 40; 5 50; 6 60]; % 6x2 matrix
    %   H = extended_hankelize(timeseries, 2, "row_index_delay", 2);
    %   % Row blocks separated by 2: x_0 and x_2 blocks
    %   % Result: H = [1 2 3 4;   % x_0, x_1, x_2, x_3
    %   %              10 20 30 40; % (first d=2 rows)
    %   %              3 4 5 6;   % x_2, x_3, x_4, x_5
    %   %              30 40 50 60]; % (second d=2 rows)
    %   % Size: (2*2) x 4 = 4 x 4
    %   % num_cols = floor((6 - (2-1)*2 - 1) / 1) + 1 = floor(3 / 1) + 1 = 3 + 1 = 4
    %
    % EXAMPLE 4: With both row and column delays
    %   timeseries = [1 10; 2 20; 3 30; 4 40; 5 50; 6 60; 7 70; 8 80; 9 90; 10 100; 11 110; 12 120]; % 12x2 matrix
    %   H = extended_hankelize(timeseries, 3, "row_index_delay", 3, "col_index_delay", 2);
    %   % Row blocks separated by 3: x_0, x_3, x_6, x_9
    %   % Column blocks separated by 2: x_0, x_2, x_4, x_6, x_8, x_10
    %   % Result: H = [1 3 5;      % x_0, x_2, x_4
    %                 10 30 50;   % (first d=2 rows)
    %                  4 6 8;      % x_3, x_5, x_7
    %                 40 60 80;   % (second d=2 rows)
    %                  7 9 11;     % x_6, x_8, x_10
    %                 70 90 110]; % (third d=2 rows)  
    %   % Size: (3*2) x 3 = 6 x 3
    %   % num_cols = floor((12 - (3-1)*3 - 1) / 2) + 1 = floor((12 - 6 - 1) / 2) + 1 = floor(5 / 2) + 1 = 2 + 1 = 3
    %
    % NOTES:
    %   - Each data point x_i is treated as a d-dimensional column vector
    %   - The function handles both row and column delays independently
    %   - Useful for multidimensional time-delay embedding and system identification
    %   - Compatible with HAVOK, DMD, and other data-driven methods

    arguments
        timeseries (:,:) double {mustBeNonempty}
        embedding_dim_multiple (1,1) int32 {mustBePositive}
        options.row_index_delay (1,1) int32 {mustBeInteger, mustBePositive} = 1
        options.col_index_delay (1,1) int32 {mustBeInteger, mustBePositive} = 1
    end
    
    [N, d] = size(timeseries);
    
    % Convert delays to double for calculations
    row_delay = double(options.row_index_delay);
    col_delay = double(options.col_index_delay);
    
    % Calculate number of columns in the Hankel matrix
    % The constraint is that the last accessed element should not exceed N:
    % (embedding_dim_multiple-1)*row_delay + (num_cols-1)*col_delay + 1 <= N % +1 comes from MATLAB's 1-indexing
    % Solving for num_cols: num_cols <= (N - (embedding_dim_multiple-1)*row_delay - 1)/col_delay + 1
    max_time_offset = (double(embedding_dim_multiple) - 1) * row_delay;
    % !!! ATTENTION FUTURE SELF OR ANY UNFORTUNATE SOUL WHO DARES TOUCH THIS CODE !!!
    % A rogue operator overload in this environment causes a catastrophic failure
    % in integer division (e.g., int32(5) / int32(2) results in 3).
    % Thanks to MATLAB's miserable type system, this bug fails silently.
    % These explicit casts are the only thing forcing correct floating-point math.
    num_cols = floor(double(N - max_time_offset - 1) / double(col_delay)) + 1;
    
    % Check if we have enough data points
    if num_cols < 1
        error(['Time series is too short for the given parameters. ' ...
               'Need at least %d points, but got %d.'], ...
               (embedding_dim_multiple - 1) * row_delay * col_delay + col_delay, N);
    end
    
    % Pre-allocate the Hankel matrix
    H = zeros(embedding_dim_multiple * d, num_cols);
    
    % Fill the Hankel matrix
    for row_block = 1:embedding_dim_multiple
        % Calculate the starting row index for this block
        start_row_in_H = (row_block - 1) * d + 1;
        end_row_in_H = row_block * d;
        
        % Calculate the starting time index for this row block
        time_offset = (row_block - 1) * row_delay;
        
        for col = 1:num_cols
            % Calculate the time index for this column
            time_idx = time_offset + (col - 1) * col_delay + 1;
            
            % Extract the d-dimensional point and place it in the matrix
            H(start_row_in_H:end_row_in_H, col) = timeseries(time_idx, :)';
        end
    end
end
