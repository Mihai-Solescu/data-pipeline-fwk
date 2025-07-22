function config = generate_config()
    %GENERATE_CONFIG Returns the configuration structure for the extended hankel HAVOK pipeline
    %
    % OUTPUT:
    %   config - Structure containing all configuration parameters

    %% Output File Configuration
    config.output_filename = 'havok_modular_results.h5';

    %% Data Pipeline Parameters
    
    % Master Simulation Parameters
    config.dt = 0.001;                         % Time step for high fidelity simulation
    config.master_timeseries_length = 1000;    % Total simulation time for master series
    
    % Parameter Grid for Comprehensive Sweep
    % Time series lengths to test (in time units)
    config.param_grid.timeseries_lengths = [30, 50, 65, 75, 100];
    
    % Index delay parameters for time-delay embedding
    config.param_grid.index_delays = int32([1, 5, 10, 15, 20]);
    
    % Variable combinations to test from Lorenz system [x, y, z]
    % Options: 'x', 'y', 'z', 'xy', 'xz', 'yz', 'xyz'
    config.param_grid.variable_combinations = {'x', 'xz'};

    % Embedding dimension multiples (number of time-delayed copies to stack)
    config.param_grid.embedding_dim_multiples = int32([30, 65, 100, 150]);
    
    % Truncation ranks for SVD (number of modes to retain)
    config.param_grid.truncation_ranks = int32([10, 15, 20, 25, 30]);
    
    % Maximum polynomial degrees for extended Hankel matrices
    config.param_grid.max_degrees = int32([2, 3]);
    
    % Maximum number of harmonics for sinusoidal terms
    config.param_grid.max_harmonics = int32([0, 1]);
    
    % Types of Hankel matrix constructions to test
    config.param_grid.hankel_types = {...
        'normal', ...           % Standard extended Hankel matrix
        'vertical', ...         % Vertical polynomial extension
        'horizontal', ...       % Horizontal polynomial extension  
        'block_vertical'...     % Block vertical extension
    };
    
    %% Variable Mapping (doesn't belong here, will move it to the correct place later)
    % Mapping from variable combination strings to column indices
    config.variable_map = containers.Map(...
        {'x', 'y', 'z', 'xy', 'xz', 'yz', 'xyz'}, ...
        {[1], [2], [3], [1,2], [1,3], [2,3], [1,2,3]});
     
end