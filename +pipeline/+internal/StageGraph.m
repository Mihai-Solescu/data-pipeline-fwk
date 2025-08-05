classdef StageGraph
    % STAGEGRAPH An immutable, encapsulated representation of a pipeline's computational graph.
    %
    %   This class takes a pipeline's stage configuration and a logger, builds a 
    %   directed acyclic graph (DAG), and provides a stable, public interface for
    %   querying the graph's structure and dependencies. The underlying graph
    %   implementation is completely hidden, and the object cannot be modified
    %   after it is created.

    properties (SetAccess = immutable)
        % Stages (struct): A copy of the original stage configurations.
        Stages struct

        % EffectiveParams (containers.Map): A map where each key is a stage
        % name and the value is a cell array of all parameters (explicit and
        % inherited) that influence that stage.
        EffectiveParams containers.Map
    end

    properties (Access = private)
        % G: The underlying MATLAB digraph object. This property is
        % private to ensure full encapsulation.
        G

        % Logger: The logger instance for reporting all events
        % and errors from this component.
        Logger
    end

    methods (Access = public)
        function obj = StageGraph(config_stages, logger)
            % STAGEGRAPH Constructs the immutable graph object.
            %   This is the only way to create a StageGraph. The constructor
            %   validates the configuration, builds the graph, checks for
            %   cycles, and resolves all parameter dependencies, logging each
            %   step.
            
            obj.Logger = logger;

            % 1. Input validation
            if ~isstruct(config_stages) || isempty(fieldnames(config_stages))
                msg = 'Input must be a non-empty struct of stage definitions.';
                obj.Logger.fatal('pipeline:StageGraph:InvalidInput', msg);
                error('pipeline:StageGraph:InvalidInput', msg);
            end
            obj.Stages = config_stages;
            stage_names = fieldnames(config_stages);
            
            % 2. Initial graph build
            temp_G = digraph();
            temp_G = addnode(temp_G, stage_names);

            for i = 1:length(stage_names)
                stage_name = stage_names{i};
                stage_config = config_stages.(stage_name);
                
                % Check if this stage has inputs
                has_inputs = isfield(stage_config, 'inputs');
                if has_inputs
                    % Use a safer approach to check if inputs is a struct
                    inputs_value = stage_config.inputs;
                    if isa(inputs_value, 'struct')
                        stage_inputs = inputs_value;
                        stage_inputs = stage_config.inputs;
                        input_fields = fieldnames(stage_inputs);
                        for j = 1:length(input_fields)
                            dependency_recipe = stage_inputs.(input_fields{j});
                            [source_stage, ~] = strtok(dependency_recipe, '.');
                            if ~ismember(source_stage, stage_names)
                                msg = sprintf('Stage ''%s'' has a dependency on ''%s'', which does not exist.', stage_name, source_stage);
                                obj.Logger.fatal('pipeline:StageGraph:InvalidDependencyTarget', msg);
                                error('pipeline:StageGraph:InvalidDependencyTarget', msg);
                            end
                            temp_G = addedge(temp_G, source_stage, stage_name);
                        end
                    end
                end
            end

            % 3. Validate that the graph is a DAG
            if ~isdag(temp_G)
                msg = 'The stage dependency graph contains a cycle. Pipelines must be a Directed Acyclic Graph (DAG).';
                obj.Logger.fatal('pipeline:StageGraph:CircularDependency', msg);
                error('pipeline:StageGraph:CircularDependency', msg);
            end
            obj.G = temp_G;

            % 4. Resolve all implicit parameter dependencies
            obj.EffectiveParams = obj.computeEffectiveParameters();
            obj.Logger.debug('pipeline:StageGraph:ParameterResolutionComplete', 'Successfully resolved all implicit and explicit parameter dependencies.');

            obj.Logger.info('pipeline:StageGraph:ConstructionSuccess', 'StageGraph constructed and validated successfully.');
        end

        % --- Graph-Wide Queries ---

        function names = getStageNames(obj)
            names = obj.G.Nodes.Name;
        end

        function sorted_names = getTopologicalSort(obj)
            sorted_indices = toposort(obj.G);
            sorted_names = obj.G.Nodes.Name(sorted_indices)';
        end

        function source_names = getSourceStages(obj)
            source_indices = find(indegree(obj.G) == 0);
            source_names = obj.G.Nodes.Name(source_indices)';
        end

        function sink_names = getSinkStages(obj)
            sink_indices = find(outdegree(obj.G) == 0);
            sink_names = obj.G.Nodes.Name(sink_indices)';
        end

        % --- Stage-Specific Queries ---

        function flag = isStage(obj, stage_name)
            flag = ismember(stage_name, obj.G.Nodes.Name);
        end

        function config = getStageConfig(obj, stage_name)
            obj.validateStageExists(stage_name);
            config = obj.Stages.(stage_name);
        end

        function predecessor_names = getPredecessors(obj, stage_name)
            obj.validateStageExists(stage_name);
            predecessor_names = predecessors(obj.G, stage_name);
            % Ensure we return a cell array of strings
            if ~iscell(predecessor_names)
                predecessor_names = cellstr(predecessor_names);
            end
            predecessor_names = predecessor_names';
        end

        function successor_names = getSuccessors(obj, stage_name)
            obj.validateStageExists(stage_name);
            successor_names = successors(obj.G, stage_name);
            % Ensure we return a cell array of strings
            if ~iscell(successor_names)
                successor_names = cellstr(successor_names);
            end
            successor_names = successor_names';
        end

        function param_names = getEffectiveParams(obj, stage_name)
            obj.validateStageExists(stage_name);
            param_names = obj.EffectiveParams(stage_name);
        end

        function param_names = getExplicitParams(obj, stage_name)
            obj.validateStageExists(stage_name);
            stage_config = obj.Stages.(stage_name);
            has_params = isfield(stage_config, 'params');
            if has_params
                % Use a safer approach to check if params is not empty
                params_value = stage_config.params;
                if ~isempty(params_value)
                    param_names = params_value;
                    param_names = stage_config.params;
                    % Ensure it's always a cell array
                    if ischar(param_names) || isstring(param_names)
                        param_names = {param_names};
                    end
                else
                    param_names = {};
                end
            else
                param_names = {};
            end
        end

        % --- Utility Methods ---

        function plot(obj)
            figure('Name', 'Pipeline Dependency Graph', 'NumberTitle', 'off');
            
            % Create edge labels based on output names
            edge_labels = {};
            edges = obj.G.Edges;
            
            % Build edge labels by examining input dependencies
            for i = 1:height(edges)
                source_stage = edges.EndNodes{i, 1};
                target_stage = edges.EndNodes{i, 2};
                
                % Get the target stage configuration to find the output name
                target_config = obj.Stages.(target_stage);
                edge_label = '';
                
                if isfield(target_config, 'inputs')
                    try
                        input_fields = fieldnames(target_config.inputs);
                        for j = 1:length(input_fields)
                            dependency_recipe = target_config.inputs.(input_fields{j});
                            [dep_source, output_part] = strtok(dependency_recipe, '.');
                            if strcmp(dep_source, source_stage) && ~isempty(output_part)
                                output_name = output_part(2:end); % Remove the leading dot
                                if isempty(edge_label)
                                    edge_label = output_name;
                                else
                                    edge_label = [edge_label, ', ', output_name];
                                end
                            end
                        end
                    catch
                        % If fieldnames fails, skip edge labeling for this edge
                        edge_label = '';
                    end
                end
                
                edge_labels{i} = edge_label;
            end
            
            % Plot the graph with edge labels
            p = plot(obj.G, 'Layout', 'layered', 'Direction', 'right', 'Sources', obj.getSourceStages());
            title('Pipeline Stage Dependency Graph');
            p.NodeLabel = obj.G.Nodes.Name;
            
            % Set edge labels if any exist
            if ~isempty(edge_labels) && any(~cellfun(@isempty, edge_labels))
                p.EdgeLabel = edge_labels;
            end
            
            % Disable LaTeX formatting for text
            set(gca, 'TickLabelInterpreter', 'none');
            set(get(gca, 'Title'), 'Interpreter', 'none');
            
            set(gca, 'XTick', [], 'YTick', []);
            box on;
        end
    end

    methods (Access = private)
        function effective_params_map = computeEffectiveParameters(obj)
            effective_params_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
            topo_indices = toposort(obj.G);
            sorted_names = obj.G.Nodes.Name(topo_indices');

            for i = 1:length(sorted_names)
                stage_name = sorted_names{i};
                explicit_params = obj.getExplicitParams(stage_name);
                predecessors_names = obj.getPredecessors(stage_name);
                inherited_params = {};
                for j = 1:length(predecessors_names)
                    inherited_params = [inherited_params, effective_params_map(predecessors_names{j})];
                end
                effective_params_map(stage_name) = unique([explicit_params, inherited_params]);
            end
        end

        function validateStageExists(obj, stage_name)
            if ~obj.isStage(stage_name)
                msg = sprintf('Attempted to access non-existent stage ''%s''.', stage_name);
                obj.Logger.fatal('pipeline:StageGraph:StageNotFound', msg);
                error('pipeline:StageGraph:StageNotFound', msg);
            end
        end
    end
end
