function outputs = compute_master_timeseries(inputs, params)
    %COMPUTE_MASTER_TIMESERIES Computes a Lorenz master timeseries for computation optimization in the extended Hankel HAVOK pipeline
    %
    % INPUTS:
    %   inputs.master_timeseries_length - Length of the master timeseries to generate
    %   inputs.dt                       - Time step for the simulation
    %
    % OUTPUTS:
    %   outputs.master_timeseries       - The generated master timeseries
    %   outputs.time_vector             - Corresponding time vector for the master timeseries

    % Add necessary paths
    addpath('../../../../../data_generate')

    % Compute the master timeseries using the lorenz_generate function
    [outputs.master_timeseries, outputs.time_vector] = lorenz_generate(...
        inputs.dt, inputs.master_timeseries_length);