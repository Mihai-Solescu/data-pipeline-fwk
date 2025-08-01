classdef ConfigValidator < handle
    % ConfigValidator - Validates pipeline configuration
    % This class is responsible for all configuration validation logic
    % according to the framework's requirements.
    
    properties (Access = private)
        logger  % Logger instance for this component
    end
    
    methods
        function obj = ConfigValidator(logger)
            % Constructor - creates a stateless validator
            obj.logger = logger;
        end

        function validateLoggingConfig(obj, config)
            % Validates only the logging configuration section
            % Throws fatal errors for invalid logging config
            %
            % Arguments:
            %   config - The configuration struct to validate
            
            if ~isfield(config, 'logging')
                return; % Logging config is optional
            end
            
            logging_config = config.logging;
            
            % Validate logging config structure
            if ~isstruct(logging_config)
                obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.logging must be a struct, but got %s', class(logging_config));
                throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                    'config.logging must be a struct'));
            end
            
            % Check for incomplete file logging configuration
            has_filepath = isfield(logging_config, 'filepath');
            has_file_level = isfield(logging_config, 'file_level');
            
            if has_filepath ~= has_file_level
                if has_filepath && ~has_file_level
                    obj.logger.fatal('pipeline:ConfigValidator:IncompleteLoggingConfig: config.logging.filepath is specified but config.logging.file_level is missing. Both must be provided together for file logging.');
                    throw(MException('pipeline:ConfigValidator:IncompleteLoggingConfig', ...
                        'config.logging.filepath is specified but config.logging.file_level is missing. Both must be provided together for file logging.'));
                elseif ~has_filepath && has_file_level
                    obj.logger.fatal('pipeline:ConfigValidator:IncompleteLoggingConfig: config.logging.file_level is specified but config.logging.filepath is missing. Both must be provided together for file logging.');
                    throw(MException('pipeline:ConfigValidator:IncompleteLoggingConfig', ...
                        'config.logging.file_level is specified but config.logging.filepath is missing. Both must be provided together for file logging.'));
                end
            end
            
            % Validate console_level if present
            if isfield(logging_config, 'console_level')
                valid_levels = {'debug', 'info', 'warning', 'error', 'fatal', 'none'};
                if ~(ischar(logging_config.console_level) || isstring(logging_config.console_level)) || ...
                   ~ismember(lower(logging_config.console_level), valid_levels)
                    obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.logging.console_level must be a valid log level string: debug, info, warning, error, fatal, none. Got: %s', ...
                        string(logging_config.console_level));
                    throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                        'config.logging.console_level must be a valid log level string: debug, info, warning, error, fatal, none'));
                end
            end
            
            % Validate file_level if present
            if isfield(logging_config, 'file_level')
                valid_levels = {'debug', 'info', 'warning', 'error', 'fatal', 'none'};
                if ~(ischar(logging_config.file_level) || isstring(logging_config.file_level)) || ...
                   ~ismember(lower(logging_config.file_level), valid_levels)
                    obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.logging.file_level must be a valid log level string: debug, info, warning, error, fatal, none. Got: %s', ...
                        string(logging_config.file_level));
                    throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                        'config.logging.file_level must be a valid log level string: debug, info, warning, error, fatal, none'));
                end
            end
            
            % Validate filepath if present
            if isfield(logging_config, 'filepath')
                if ~ischar(logging_config.filepath) && ~isstring(logging_config.filepath)
                    obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.logging.filepath must be a string or char array, but got %s', class(logging_config.filepath));
                    throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                        'config.logging.filepath must be a string or char array'));
                end
            end
        end
        
        function validateBasicConfig(obj, config)
            % Validates the basic configuration (excluding stage graph)
            % Throws fatal errors for critical issues
            % Logs warnings for non-critical issues
            %
            % Arguments:
            %   config - The configuration struct to validate
            
            % Surface checks - required top-level fields
            obj.validateSurfaceFields(config);
            
            % Parameter checks
            obj.validateParameterSpace(config);
            
            % Check for unexpected fields
            obj.checkForUnexpectedFields(config);
        end
    end
    
    methods (Access = private)
        function validateSurfaceFields(obj, config)
            % Validates required top-level fields exist
            %
            % Arguments:
            %   config - The configuration struct to validate
            
            required_fields = {'stages', 'params', 'output_filename'};
            
            for i = 1:length(required_fields)
                field = required_fields{i};
                if ~isfield(config, field)
                    obj.logger.fatal('pipeline:ConfigValidator:MissingRequiredField: Required field config.%s is missing', field);
                    throw(MException('pipeline:ConfigValidator:MissingRequiredField', ...
                        'Required field config.%s is missing', field));
                end
            end
            
            % Validate field types
            if ~isstruct(config.stages)
                obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.stages must be a struct, but got %s', class(config.stages));
                throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                    'config.stages must be a struct'));
            end
            
            if ~isstruct(config.params)
                obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.params must be a struct, but got %s', class(config.params));
                throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                    'config.params must be a struct'));
            end
            
            if ~ischar(config.output_filename) && ~isstring(config.output_filename)
                obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.output_filename must be a string or char array, but got %s', class(config.output_filename));
                throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                    'config.output_filename must be a string or char array'));
            end
        end
        
        function validateParameterSpace(obj, config)
            % Validates the parameter space definition
            %
            % Arguments:
            %   config - The configuration struct to validate
            
            % Check for required params subfields
            if ~isfield(config.params, 'globals')
                obj.logger.fatal('pipeline:ConfigValidator:MissingRequiredField: Required field config.params.globals is missing');
                throw(MException('pipeline:ConfigValidator:MissingRequiredField', ...
                    'Required field config.params.globals is missing'));
            end
            
            if ~isfield(config.params, 'grid')
                obj.logger.fatal('pipeline:ConfigValidator:MissingRequiredField: Required field config.params.grid is missing');
                throw(MException('pipeline:ConfigValidator:MissingRequiredField', ...
                    'Required field config.params.grid is missing'));
            end
            
            % Validate types
            if ~isstruct(config.params.globals)
                obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.params.globals must be a struct, but got %s', class(config.params.globals));
                throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                    'config.params.globals must be a struct'));
            end
            
            if ~isstruct(config.params.grid)
                obj.logger.fatal('pipeline:ConfigValidator:InvalidFieldType: config.params.grid must be a struct, but got %s', class(config.params.grid));
                throw(MException('pipeline:ConfigValidator:InvalidFieldType', ...
                    'config.params.grid must be a struct'));
            end
            
            % Check for parameter name collisions
            global_names = fieldnames(config.params.globals);
            grid_names = fieldnames(config.params.grid);
            
            common_names = intersect(global_names, grid_names);
            if ~isempty(common_names)
                obj.logger.fatal('pipeline:ConfigValidator:ParameterNameCollision: Parameter names must be unique across globals and grid. Collisions found: %s', ...
                    strjoin(common_names, ', '));
                throw(MException('pipeline:ConfigValidator:ParameterNameCollision', ...
                    'Parameter names must be unique across globals and grid. Collisions found: %s', ...
                    strjoin(common_names, ', ')));
            end
        end
        
        function checkForUnexpectedFields(obj, config)
            % Checks for unexpected fields and logs warnings
            %
            % Arguments:
            %   config - The configuration struct to validate
            
            expected_top_level = {'stages', 'params', 'output_filename', 'logging', ...
                                  'error_mode', 'num_workers'};
            actual_fields = fieldnames(config);
            
            unexpected = setdiff(actual_fields, expected_top_level);
            for i = 1:length(unexpected)
                obj.logger.warning('pipeline:ConfigValidator:UnexpectedField: Unexpected field found in config: %s. This field will be ignored.', ...
                    unexpected{i});
            end
        end
        
        % ================================================================
        % UNUSED STAGE GRAPH VALIDATION METHODS
        % These methods are isolated and not used in basic validation
        % ================================================================
        
        function validateGraphIntegrity(obj, config) %#ok<INUSD>
            % Validates the stage graph integrity
            % NOTE: This method is unused in the refactored version
            %
            % Arguments:
            %   config - The configuration struct to validate
            
            % Build a temporary graph to check for cycles and dependencies
            try
                builder = pipeline.utility.StageGraphBuilder(config);
                G = builder.build();
                
                % Check for circular dependencies
                if ~isdag(G)
                    throw(MException('pipeline:Validator:CircularDependency', ...
                        'The stage graph contains circular dependencies'));
                end
                
                % Validate dependency targets
                obj.validateDependencyTargets(config);
                
            catch ME
                if strcmp(ME.identifier, 'pipeline:Validator:CircularDependency') || ...
                   strcmp(ME.identifier, 'pipeline:Validator:InvalidDependencyTarget')
                    rethrow(ME);
                else
                    throw(MException('pipeline:Validator:GraphBuildError', ...
                        'Failed to build stage graph: %s', ME.message));
                end
            end
        end
        
        function validateDependencyTargets(obj, config) %#ok<INUSD>
            % Validates that all dependency recipes point to valid stages and outputs
            % NOTE: This method is unused in the refactored version
            %
            % Arguments:
            %   config - The configuration struct to validate
            
            stage_names = fieldnames(config.stages);
            
            for i = 1:length(stage_names)
                stage_name = stage_names{i};
                stage_config = config.stages.(stage_name);
                
                if isfield(stage_config, 'inputs') && ~isempty(stage_config.inputs)
                    input_names = fieldnames(stage_config.inputs);
                    
                    for j = 1:length(input_names)
                        input_name = input_names{j};
                        dependency_recipe = stage_config.inputs.(input_name);
                        
                        % Parse dependency recipe (format: 'stage_name.output_name')
                        if ~ischar(dependency_recipe) && ~isstring(dependency_recipe)
                            throw(MException('pipeline:Validator:InvalidDependencyTarget', ...
                                'Dependency recipe for stage %s input %s must be a string', ...
                                stage_name, input_name));
                        end
                        
                        parts = split(dependency_recipe, '.');
                        if length(parts) ~= 2
                            throw(MException('pipeline:Validator:InvalidDependencyTarget', ...
                                'Invalid dependency recipe format for stage %s input %s: %s. Expected format: stage_name.output_name', ...
                                stage_name, input_name, dependency_recipe));
                        end
                        
                        target_stage = parts{1};
                        target_output = parts{2};
                        
                        % Check if target stage exists
                        if ~isfield(config.stages, target_stage)
                            throw(MException('pipeline:Validator:InvalidDependencyTarget', ...
                                'Stage %s input %s references non-existent stage: %s', ...
                                stage_name, input_name, target_stage));
                        end
                        
                        % Check if target output exists
                        target_stage_config = config.stages.(target_stage);
                        if ~isfield(target_stage_config, 'outputs') || isempty(target_stage_config.outputs)
                            throw(MException('pipeline:Validator:InvalidDependencyTarget', ...
                                'Stage %s input %s references stage %s which has no outputs', ...
                                stage_name, input_name, target_stage));
                        end
                        
                        % Check if the specific output exists
                        outputs = target_stage_config.outputs;
                        output_found = false;
                        for k = 1:length(outputs)
                            if isfield(outputs{k}, 'name') && strcmp(outputs{k}.name, target_output)
                                output_found = true;
                                break;
                            end
                        end
                        
                        if ~output_found
                            throw(MException('pipeline:Validator:InvalidDependencyTarget', ...
                                'Stage %s input %s references non-existent output %s from stage %s', ...
                                stage_name, input_name, target_output, target_stage));
                        end
                    end
                end
            end
        end
    end
end
