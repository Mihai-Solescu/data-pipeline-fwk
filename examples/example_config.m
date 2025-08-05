function config = example_config()
    % Example configuration demonstrating the validation framework
    
    config = struct();
    
    % Required top-level fields
    config.output_directory = 'example_output';
    
    % Parameter space definition
    config.params = struct();
    config.params.globals = struct(...
        'dt', 0.001, ...
        'num_samples', 1000, ...
        'noise_level', 0.1);
    
    config.params.grid = struct(...
        'truncation_rank', [10, 15, 20], ...
        'method', {{'svd', 'eig'}}, ...
        'window_size', [50, 100]);
    
    % Optional: Parameter filter
    config.params.filter = @param_filter;
    
    % Stage definitions
    config.stages = struct();
    
    % Stage 1: Data generation (no inputs)
    config.stages.generate_data = struct(...
        'function', @generate_time_series, ...
        'inputs', struct(), ...
        'params', {{'dt', 'num_samples', 'noise_level'}}, ...
        'outputs', {{struct('name', 'raw_timeseries', 'storage_policy', 'persistent')}});
    
    % Stage 2: Preprocessing (depends on stage 1)
    config.stages.preprocess = struct(...
        'function', @preprocess_data, ...
        'inputs', struct('timeseries', 'generate_data.raw_timeseries'), ...
        'params', {{'window_size'}}, ...
        'outputs', {{struct('name', 'windowed_data', 'storage_policy', 'persistent')}});
    
    % Stage 3: Analysis (depends on stage 2)
    config.stages.analyze = struct(...
        'function', @analyze_data, ...
        'inputs', struct('data', 'preprocess.windowed_data'), ...
        'params', {{'truncation_rank', 'method'}}, ...
        'outputs', {{struct('name', 'analysis_result', 'storage_policy', @conditional_storage)}});
    
    % Stage 4: Global summary (depends on stage 3, runs once)
    config.stages.summarize = struct(...
        'function', @create_summary, ...
        'inputs', struct('results', 'analyze.analysis_result'), ...
        'params', {{}}, ...
        'outputs', {{struct('name', 'summary_report', 'storage_policy', 'persistent')}}, ...
        'execution_mode', 'global');
    
    % Optional configuration
    config.error_mode = 'resilient';
    config.num_workers = 2;
    
    % Logging configuration
    config.logging = struct(...
        'console_level', mlog.Level.INFO, ...
        'file_level', mlog.Level.DEBUG, ...
        'filepath', 'pipeline_example.log');
end

% Helper functions for the configuration

function keep = param_filter(p, G)
    % Example filter: only keep combinations where window_size <= num_samples/10
    keep = p.window_size <= p.num_samples / 10;
end

function should_store = conditional_storage(p, G)
    % Example conditional storage: only store results for SVD method
    should_store = strcmp(p.method, 'svd');
end

% Example stage functions (these would normally be in separate files)

function outputs = generate_time_series(inputs, params)
    % Generate synthetic time series data
    t = (0:params.num_samples-1) * params.dt;
    signal = sin(2*pi*t) + 0.5*sin(4*pi*t) + params.noise_level*randn(size(t));
    outputs.raw_timeseries = signal(:);
end

function outputs = preprocess_data(inputs, params)
    % Create windowed data
    data = inputs.timeseries;
    windowed = buffer(data, params.window_size, params.window_size/2);
    outputs.windowed_data = windowed;
end

function outputs = analyze_data(inputs, params)
    % Perform analysis based on method and rank
    data = inputs.data;
    
    if strcmp(params.method, 'svd')
        [U, S, V] = svd(data, 'econ');
        result = diag(S);
    else % 'eig'
        C = data' * data;
        result = eig(C);
    end
    
    % Truncate to specified rank
    result = result(1:min(params.truncation_rank, length(result)));
    outputs.analysis_result = result;
end

function outputs = create_summary(inputs, params)
    % Create a summary of all results
    if iscell(inputs.results)
        all_results = cat(1, inputs.results{:});
    else
        all_results = inputs.results;
    end
    
    summary = struct();
    summary.mean_value = mean(all_results);
    summary.std_value = std(all_results);
    summary.min_value = min(all_results);
    summary.max_value = max(all_results);
    summary.num_runs = length(inputs.results);
    
    outputs.summary_report = summary;
end
