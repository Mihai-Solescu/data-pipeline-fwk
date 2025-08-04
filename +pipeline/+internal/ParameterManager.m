classdef ParameterManager < handle
    % ParameterManager - Service for managing parameter space generation and projection
    %
    % This class is responsible for:
    % 1. Generating the full Cartesian product of grid parameters
    % 2. Merging with global parameters
    % 3. Applying filter functions to produce the definitive Approved_Runs list
    % 4. Providing efficient task projection for stages
    %
    % The ParameterManager is instantiated once at the beginning of a pipeline run
    % and performs expensive computations upfront to enable efficient projections
    % during orchestration.
    
    properties (Access = private)
        approved_runs  % Cell array of parameter structs representing valid runs
        logger         % Logger instance for this service
    end
    
    methods
        function obj = ParameterManager(config_params, logger)
            % Constructor - Initialize ParameterManager with parameter configuration
            %
            % Inputs:
            %   config_params - struct containing:
            %     .globals - struct with constant parameters
            %     .grid - struct with arrays of values to sweep
            %     .filter - (optional) function handle for filtering runs
            %   logger - mlog.Logger instance
            
            if nargin < 2
                error('pipeline:ParameterManager:InvalidArguments', ...
                    'ParameterManager requires config_params and logger arguments');
            end
            
            obj.logger = logger;
            
            % Validate inputs
            obj.validateConfigParams(config_params);
            
            % Generate the full parameter space
            obj.approved_runs = obj.generateApprovedRuns(config_params);
        end
        
        function projected_tasks = getProjectedTasks(obj, effective_param_names)
            % Get the minimal set of unique tasks for a stage
            %
            % This method projects the approved runs onto the specified parameter
            % space to generate the minimal set of unique tasks needed for a stage.
            %
            % Inputs:
            %   effective_param_names - cell array of parameter names that affect the stage
            %
            % Returns:
            %   projected_tasks - cell array of parameter structs representing unique tasks
            
            if isempty(effective_param_names)
                % Stage has no effective parameters - return single empty task
                projected_tasks = {struct()};
                obj.logger.debug('pipeline:ParameterManager:ProjectionComplete: Projected onto empty parameter set, returning single empty task');
                return;
            end
            
            % Use a containers.Map to efficiently find unique projections
            unique_projections = containers.Map();
            
            for i = 1:length(obj.approved_runs)
                run = obj.approved_runs{i};
                
                % Project this run onto the effective parameter space
                projected_run = struct();
                for j = 1:length(effective_param_names)
                    param_name = effective_param_names{j};
                    if isfield(run, param_name)
                        projected_run.(param_name) = run.(param_name);
                    else
                        error('pipeline:ParameterManager:MissingParameter', ...
                            'Parameter "%s" not found in approved run', param_name);
                    end
                end
                
                % Create a hash key for this projection to detect uniqueness
                key = obj.createStructHash(projected_run);
                
                % Store unique projections
                if ~isKey(unique_projections, key)
                    unique_projections(key) = projected_run;
                end
            end
            
            % Convert map values to cell array
            projected_tasks = values(unique_projections);
            
            obj.logger.debug('pipeline:ParameterManager:ProjectionComplete: Projected %d approved runs onto %d effective parameters, resulting in %d unique tasks', ...
                length(obj.approved_runs), length(effective_param_names), length(projected_tasks));
        end
        
        function num_runs = getNumApprovedRuns(obj)
            % Get the total number of approved runs
            num_runs = length(obj.approved_runs);
        end
        
        function runs = getApprovedRuns(obj)
            % Get a copy of all approved runs
            runs = obj.approved_runs;
        end
    end
    
    methods (Access = private)
        function validateConfigParams(~, config_params)
            % Validate the structure of config_params
            
            if ~isstruct(config_params)
                error('pipeline:ParameterManager:InvalidConfigParams', ...
                    'config_params must be a struct');
            end
            
            % Validate globals field
            if ~isfield(config_params, 'globals')
                config_params.globals = struct(); % Default to empty if missing
            elseif ~isstruct(config_params.globals)
                error('pipeline:ParameterManager:InvalidGlobals', ...
                    'config.params.globals must be a struct');
            end
            
            % Validate grid field
            if ~isfield(config_params, 'grid')
                config_params.grid = struct(); % Default to empty if missing
            elseif ~isstruct(config_params.grid)
                error('pipeline:ParameterManager:InvalidGrid', ...
                    'config.params.grid must be a struct');
            end
            
            % Validate filter field if present
            if isfield(config_params, 'filter') && ~isempty(config_params.filter)
                if ~isa(config_params.filter, 'function_handle')
                    error('pipeline:ParameterManager:InvalidFilterFunction', ...
                        'config.params.filter must be a function handle');
                end
            end
            
            % Check for parameter name collisions between globals and grid
            global_names = fieldnames(config_params.globals);
            grid_names = fieldnames(config_params.grid);
            
            common_names = intersect(global_names, grid_names);
            if ~isempty(common_names)
                error('pipeline:ParameterManager:ParameterNameCollision', ...
                    'Parameter names must be unique across globals and grid. Collisions: %s', ...
                    strjoin(common_names, ', '));
            end
        end
        
        function approved_runs = generateApprovedRuns(obj, config_params)
            % Generate the definitive list of approved parameter runs
            
            % Step 1: Generate full Cartesian product of grid parameters
            grid_runs = obj.generateGridCartesianProduct(config_params.grid);
            
            obj.logger.info('pipeline:ParameterManager:GridGenerationComplete: Generated %d potential runs from parameter grid', ...
                length(grid_runs));
            
            % Step 2: Merge with globals
            merged_runs = obj.mergeWithGlobals(grid_runs, config_params.globals);
            
            % Step 3: Apply filter if present
            if isfield(config_params, 'filter') && ~isempty(config_params.filter)
                approved_runs = obj.applyFilter(merged_runs, config_params.filter, config_params.grid);
            else
                approved_runs = merged_runs;
            end
            
            if isempty(approved_runs)
                obj.logger.warning('pipeline:ParameterManager:NoApprovedRuns: The combination of parameter grid and filter function resulted in zero valid runs');
            else
                obj.logger.info('pipeline:ParameterManager:FilteringComplete: Filter applied successfully, %d approved runs remain', ...
                    length(approved_runs));
            end
        end
        
        function grid_runs = generateGridCartesianProduct(~, grid_struct)
            % Generate Cartesian product of grid parameters
            
            if isempty(fieldnames(grid_struct))
                % No grid parameters - return single empty run
                grid_runs = {struct()};
                return;
            end
            
            param_names = fieldnames(grid_struct);
            param_values_cell = cell(length(param_names), 1);
            
            % Convert all parameter values to cell arrays
            for k = 1:length(param_names)
                values = grid_struct.(param_names{k});
                
                if iscell(values)
                    param_values_cell{k} = values;
                elseif ischar(values) && size(values, 1) == 1
                    % Single string
                    param_values_cell{k} = {values};
                elseif ischar(values)
                    % Multiple strings (char array)
                    param_values_cell{k} = cellstr(values);
                else
                    % Numeric/logical array
                    param_values_cell{k} = num2cell(values);
                end
            end
            
            % Generate combinations using iterative approach
            combinations = generateAllCombinations(param_values_cell);
            
            % Convert combinations to parameter structs
            grid_runs = cell(size(combinations, 1), 1);
            for m = 1:size(combinations, 1)
                run_struct = struct();
                for n = 1:length(param_names)
                    run_struct.(param_names{n}) = combinations{m, n};
                end
                grid_runs{m} = run_struct;
            end
            
            function combos = generateAllCombinations(param_values_cell)
                % Generate all combinations iteratively to avoid nested function issues
                
                num_params = length(param_values_cell);
                if num_params == 0
                    combos = {};
                    return;
                end
                
                % Calculate total number of combinations
                total_combinations = 1;
                for p = 1:num_params
                    total_combinations = total_combinations * length(param_values_cell{p});
                end
                
                combos = cell(total_combinations, num_params);
                
                % Generate combinations using nested loops approach
                combo_idx = 1;
                indices = ones(1, num_params);
                
                for combo = 1:total_combinations
                    % Fill current combination
                    for param_idx = 1:num_params
                        combos{combo_idx, param_idx} = param_values_cell{param_idx}{indices(param_idx)};
                    end
                    
                    % Increment indices (like odometer)
                    carry = 1;
                    for param_idx = num_params:-1:1
                        if carry
                            indices(param_idx) = indices(param_idx) + 1;
                            if indices(param_idx) > length(param_values_cell{param_idx})
                                indices(param_idx) = 1;
                                carry = 1;
                            else
                                carry = 0;
                            end
                        end
                    end
                    
                    combo_idx = combo_idx + 1;
                end
            end
        end
        
        function merged_runs = mergeWithGlobals(~, grid_runs, globals_struct)
            % Merge grid runs with global parameters
            
            merged_runs = cell(size(grid_runs));
            global_names = fieldnames(globals_struct);
            
            for r = 1:length(grid_runs)
                merged_run = grid_runs{r};
                
                % Add all global parameters
                for g = 1:length(global_names)
                    global_name = global_names{g};
                    merged_run.(global_name) = globals_struct.(global_name);
                end
                
                merged_runs{r} = merged_run;
            end
        end
        
        function filtered_runs = applyFilter(obj, runs, filter_func, grid_struct)
            % Apply user-provided filter function to runs
            
            filtered_runs = {};
            
            for f = 1:length(runs)
                run = runs{f};
                
                try
                    % Apply filter function with signature: f(p, G)
                    keep_run = filter_func(run, grid_struct);
                    
                    if ~islogical(keep_run) || ~isscalar(keep_run)
                        error('pipeline:ParameterManager:FilterFunctionError', ...
                            'Filter function must return a scalar logical value, got %s', class(keep_run));
                    end
                    
                    if keep_run
                        filtered_runs{end+1} = run; %#ok<AGROW>
                    end
                    
                catch ME
                    obj.logger.fatal('pipeline:ParameterManager:FilterFunctionError: Error in filter function for run %d: %s', ...
                        f, ME.message);
                    % Rethrow with framework error ID for consistency
                    error('pipeline:ParameterManager:FilterFunctionError', ...
                        'Error in filter function for run %d: %s', f, ME.message);
                end
            end
        end
        
        function hash_str = createStructHash(~, s)
            % Create a deterministic hash string for a struct
            % This is used for efficient uniqueness detection in projections
            
            if isempty(fieldnames(s))
                hash_str = 'empty_struct';
                return;
            end
            
            % Sort field names for deterministic ordering
            field_names = sort(fieldnames(s));
            
            % Create a string representation
            str_parts = cell(length(field_names), 1);
            for h = 1:length(field_names)
                field_name = field_names{h};
                value = s.(field_name);
                
                if isnumeric(value)
                    value_str = sprintf('%.15g', value); % High precision for numbers
                elseif islogical(value)
                    value_str = sprintf('%d', value);
                elseif ischar(value)
                    value_str = value;
                else
                    value_str = sprintf('%s', class(value)); % Fallback for other types
                end
                
                str_parts{h} = sprintf('%s=%s', field_name, value_str);
            end
            
            hash_str = strjoin(str_parts, '|');
        end
    end
end
