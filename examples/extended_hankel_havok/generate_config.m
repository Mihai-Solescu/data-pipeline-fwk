function config = generate_config()
    %GENERATE_CONFIG Returns the configuration structure for the extended hankel HAVOK pipeline
    %
    % OUTPUT:
    %   config - Structure containing all configuration parameters

    %% Output File Configuration
    config.output_filename = 'havok_modular_results.h5';

    %% General Configuration
    config.cpu = 8;  % Number of CPUs to use for parallel processing
    
    %% Data Pipeline Parameters
    
    % Master Simulation Parameters
    config.dt = 0.001;                         % Time step for high fidelity simulation
    config.master_timeseries_length = 1000;    % Total simulation time for master series
    
    % Parameter Grid for Comprehensive Sweep
    config.param_grid.timeseries_lengths = [30, 50]; % Time series lengths to test (in time units)
    config.param_grid.index_delays = int32([1, 5]); % Index delay parameters for time-delay embedding
    config.param_grid.variable_combinations = {'x', 'xz'}; % Variable combinations to test from Lorenz system [x, y, z] % Options: 'x', 'y', 'z', 'xy', 'xz', 'yz', 'xyz'
    config.param_grid.embedding_dim_multiples = int32([30, 50]); % Embedding dimension multiples (number of time-delayed copies to stack)
    config.param_grid.truncation_ranks = int32([10, 15]); % Truncation ranks for SVD (number of modes to retain)
    config.param_grid.hankel_max_degrees = int32([2, 3]); % Maximum polynomial degrees for extended Hankel matrices
    config.param_grid.hankel_max_harmonics = int32([0, 1]); % Maximum harmonics for polynomial extensions
    config.param_grid.library_max_degrees = int32([1]); % Maximum polynomial degrees for regression library
    config.param_grid.library_max_harmonics = int32([0]); % Maximum harmonics for regression library
    config.param_grid.lambda = int32([0]); % Sparsification parameter for regression

    % Types of Hankel matrix constructions to test
    config.param_grid.hankel_types = {...
        'normal', ...           % Standard extended Hankel matrix
        'vertical', ...         % Vertical polynomial extension
        'horizontal', ...       % Horizontal polynomial extension  
        'block_vertical'...     % Block vertical extension
    };
    
    %% Stages Configuration
    config.stages = struct();

    % Stage 1: Master Timeseries Generation
    config.stages(1).name = 'compute_master_timeseries';
    config.stages(1).params = {'master_timeseries_length', 'dt'};
    config.stages(1).inputs = {};
    config.stages(1).outputs = {'master_timeseries', 'time_vector'};
    config.stages(1).function = @compute_master_timeseries;
    config.stages(1).storage_policy = 'memory';
    config.stages(1).execution_mode = 'singleton'; % Having no inputs, this would be inferred anyway

    % Stage 2: Hankel Matrix Computation
    config.stages(2).name = 'compute_hankel';
    config.stages(2).params = {'hankel_type', 'max_degrees', 'max_harmonics'};
    config.stages(2).inputs = {'compute_master_timeseries.master_timeseries', ...
                               'compute_master_timeseries.time_vector'};
    config.stages(2).outputs = {'H'};
    config.stages(2).function = @compute_hankel;
    config.stages(2).storage_policy = 'memory';
    config.stages(2).execution_mode = 'per_run';

    % Stage 3: Singular Value Decomposition (SVD)
    config.stages(3).name = 'compute_svd';
    config.stages(3).params = {'truncation_rank'};
    config.stages(3).inputs = {'compute_hankel.H'};
    config.stages(3).outputs = {'U', 'S', 'V', 'singular_values'};
    config.stages(3).function = @processing.compute_svd;
    config.stages(3).storage_policy = 'memory';
    config.stages(3).execution_mode = 'per_run';
    
    % Stage 4: Numerical Derivative Calculation
    config.stages(4).name = 'compute_numerical_derivative';
    config.stages(4).params = {'dt'};
    config.stages(4).inputs = {'compute_svd.V'};
    config.stages(4).outputs = {'dVdt'};
    config.stages(4).function = @processing.compute_numerical_derivative;
    config.stages(4).storage_policy = 'memory';
    config.stages(4).execution_mode = 'per_run';

    % Stage 5: Regression Library Construction
    config.stages(5).name = 'construct_regression_library';
    config.stages(5).params = {'library_max_degrees', 'library_max_harmonics', 'truncation_rank'};
    config.stages(5).inputs = {'compute_svd.V'};
    config.stages(5).outputs = {'Theta'};
    config.stages(5).function = @construct_regression_library;
    config.stages(5).storage_policy = 'memory';
    config.stages(5).execution_mode = 'per_run';

    % Stage 6: Sparse Regression
    config.stages(6).name = 'perform_sparse_regression';
    config.stages(6).params = {};
    config.stages(6).inputs = {'construct_regression_library.Theta', ...
                               'compute_numerical_derivative.dVdt'};
    config.stages(6).outputs = {'Xi', 'A', 'B'};
    config.stages(6).function = @perform_sparse_regression;
    config.stages(6).storage_policy = 'persistent'; % Store results for reuse
    config.stages(6).execution_mode = 'per_run';

    % Stage 7: Model Assembly and Reconstruction
    config.stages(7).name = 'reconstruction';
    config.stages(7).params = {'dt', 'truncation_rank'};
    config.stages(7).inputs = {'perform_sparse_regression.Xi', ...
                               'perform_sparse_regression.A', ...
                               'perform_sparse_regression.B', ...
                               'compute_svd.U', ...
                               'compute_svd.S', ...
                               'compute_svd.V'};
    config.stages(7).outputs = {'y', 't_recon', 'model_eigenvalues', 'forcing_term'};
    config.stages(7).function = @compute_reconstruction;
    config.stages(7).storage_policy = 'memory';
    config.stages(7).execution_mode = 'per_run';

end