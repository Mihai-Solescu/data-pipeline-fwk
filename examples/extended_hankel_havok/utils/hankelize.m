function H = hankelize(timeseries, embedding_dim, options)
    % HANKELIZE Creates a Hankel matrix from a 1D time series for time-delay embedding.
    %
    % A Hankel matrix is a matrix where each anti-diagonal has constant values.
    % In the context of dynamical systems, it's used for time-delay embedding
    % to reconstruct the phase space of a system from a single scalar time series.
    % This is the classic time-delay embedding method for scalar observations.
    %
    % INPUTS:
    %   timeseries    - Input time series data (N x 1 column vector) where:
    %                   N is the number of time points (scalar observations)
    %   embedding_dim  - Embedding dimension (positive integer)
    %                   Number of time-delayed copies to stack vertically
    %                   This corresponds to the number of rows in the Hankel matrix
    %   options.index_delay - Time delay between consecutive embeddings 
    %                         (default: 1, positive integer)
    %                         Controls both row and column delays simultaneously
    %
    % OUTPUTS:
    %   H - Hankel matrix of size (embedding_dim x num_cols) where:
    %       - Each row contains the time series shifted by index_delay time steps from previous row
    %       - Each column advances by index_delay time steps from previous column
    %       - H(i,j) = timeseries((i-1)*τ + (j-1)*τ + 1) where τ = index_delay
    %       - num_cols = floor((N - (embedding_dim-1)*τ - 1)/τ) + 1
    %
    % STRUCTURE:
    %   The Hankel matrix has the structure:
    %   H = [x_0           x_0+τ         x_0+2τ      ...  ]
    %       [x_0+τ         x_0+2τ        x_0+3τ      ...  ]
    %       [x_0+2τ        x_0+3τ        x_0+4τ      ...  ]
    %       [  ...           ...           ...       ...  ]
    %   
    %   where:
    %   - x_i represents the i-th scalar observation (0-based indexing in description)
    %   - τ = index_delay (time delay)
    %   - Each row starts τ time steps later than the previous row
    %   - Each column advances by τ time steps
    %
    % EXAMPLE 1: Basic Hankel matrix with no delay (τ=1)
    %   timeseries = [1; 2; 3; 4; 5; 6];
    %   H = hankelize(timeseries, 3);
    %   % Result: H = [1 2 3 4;    % x_0, x_0+τ, x_0+2τ, x_0+3τ (τ=1)
    %   %              2 3 4 5;    % x_0+τ, x_0+2τ, x_0+3τ, x_0+4τ
    %   %              3 4 5 6];   % x_0+2τ, x_0+3τ, x_0+4τ, x_0+5τ
    %   % Size: 3 x 4
    %   % num_cols = 6 - (3-1)*1 = 4
    %
    % EXAMPLE 2: With time delay (τ=2)
    %   timeseries = [1; 2; 3; 4; 5; 6; 7; 8];
    %   H = hankelize(timeseries, 3, "index_delay", 2);
    %   % Result: H = [1 3;        % x_0, x_0+2τ (τ=2)
    %   %              3 5;        % x_0+τ, x_0+3τ  
    %   %              5 7];       % x_0+2τ, x_0+4τ
    %   % Size: 3 x 2
    %   % num_cols = floor((8 - (3-1)*2 - 1)/2) + 1 = floor(3/2) + 1 = 2
    %
    % EXAMPLE 3: Larger delay (τ=3)
    %   timeseries = [1; 2; 3; 4; 5; 6; 7; 8; 9; 10];
    %   H = hankelize(timeseries, 2, "index_delay", 3);
    %   % Result: H = [1 4 7;      % x_0, x_0+3τ, x_0+6τ (τ=3)
    %   %              4 7 10];    % x_0+τ, x_0+4τ, x_0+7τ
    %   % Size: 2 x 3  
    %   % num_cols = floor((10 - (2-1)*3 - 1)/3) + 1 = floor(6/3) + 1 = 3
    %
    % APPLICATIONS:
    %   - Time-delay embedding for dynamical systems reconstruction
    %   - Phase space reconstruction from scalar observations
    %   - Nonlinear time series analysis
    %   - Delay coordinate embedding (Takens' embedding theorem)
    %   - Compatible with DMD, HAVOK, and other data-driven methods
    %
    % NOTES:
    %   - For multidimensional time series, use extended_hankelize instead
    %   - The time delay τ controls the separation between observations
    %   - Larger delays can reveal different timescales in the dynamics
    %   - The embedding dimension should be chosen based on the system's complexity
    %   - Common rule: embedding dimension ≥ 2 * (fractal dimension) + 1

    arguments
        timeseries (:,1) double {mustBeNonempty}
        embedding_dim (1,1) int32 {mustBePositive}
        options.index_delay (1,1) int32 {mustBeInteger, mustBePositive} = 1
    end
        
    % Calculate the number of columns in the Hankel matrix
    % For a proper Hankel matrix with constant skew-diagonals:
    % Maximum index accessed = (embedding_dim-1)*τ + (num_cols-1)*τ + 1
    % This must be ≤ N, so: num_cols ≤ (N - (embedding_dim-1)*τ - 1)/τ + 1
    % Convert to double to avoid integer division issues
    N = length(timeseries);
    embedding_dim_double = double(embedding_dim);
    delay_double = double(options.index_delay);
    
    % Calculate maximum number of columns that fit
    max_cols = floor(double(N - (embedding_dim_double - 1) * delay_double - 1) / delay_double) + 1;
    
    % Check if we have enough data points
    if max_cols < 1
        error('Time series is too short for the given embedding dimension and delay.');
    end
    
    % Number of columns in the Hankel matrix
    num_cols = max_cols;
    
    % Pre-allocate the Hankel matrix
    H = zeros(embedding_dim, num_cols);
    
    % Fill the Hankel matrix
    for i = 1:embedding_dim
        for j = 1:num_cols
            % Hankel matrix property: H(i,j) = timeseries((i-1)*τ + (j-1)*τ + 1)
            % This ensures constant skew-diagonals
            time_idx = (i - 1) * delay_double + (j - 1) * delay_double + 1;
            H(i, j) = timeseries(time_idx);
        end
    end
end