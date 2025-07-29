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
    config.param_grid.timeseries_lengths = [30, 50];
    
    % Index delay parameters for time-delay embedding
    config.param_grid.index_delays = int32([1, 5]);
    
    % Variable combinations to test from Lorenz system [x, y, z]
    % Options: 'x', 'y', 'z', 'xy', 'xz', 'yz', 'xyz'
    config.param_grid.variable_combinations = {'x', 'xz'};

    % Embedding dimension multiples (number of time-delayed copies to stack)
    config.param_grid.embedding_dim_multiples = int32([30, 50]);
    
    % Truncation ranks for SVD (number of modes to retain)
    config.param_grid.truncation_ranks = int32([10, 15]);
    
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
    
    %% Stages Configuration
    config.stages = struct();

    config.stages(1).name = 'compute_master_timeseries';
    config.stages(1).params = {'master_timeseries_length', 'dt'};
    config.stages(1).inputs = {};
    config.stages(1).outputs = {'master_timeseries', 'time_vector'};
    config.stages(1).function = @compute_master_timeseries;
    config.stages(1).storage_policy = 'memory';
    config.stages(1).execution_mode = 'global'; % Having no inputs, this would be inferred anyway

    config.stages(2).name = 'compute_hankel_havok';
    config.stages(2).params = {'hankel_type', 'max_degrees', 'max_harmonics'};
    config.stages(2).inputs = {'master_timeseries', 'time_vector'};
    config.stages(2).outputs = {'hankel_matrix', 'havok_model'};
    config.stages(2).function = @compute_hankel_havok;
    config.stages(2).storage_policy = 'memory';
    config.stages(2).execution_mode = 'global'; % Having no dependencies, this would be inferred anyway

end