% +pipeline/ProvenanceHasher.m
classdef ProvenanceHasher
    % PROVENANCEHASHER Computes the definitive Provenance Hash for a task.
    %   This service encapsulates the logic for the three-part hashing
    %   system (Code, Parameters, Inputs) as defined in the architecture.
    %   It uses the low-level Hasher utility to perform the actual hashing.

    properties (Access = private)
        StageGraph % An instance of the pipeline's StageGraph
        CodeHashMap containers.Map % A cache for code hashes to avoid re-reading files
        Logger % The logger instance for reporting events and errors
    end

    methods
        function obj = ProvenanceHasher(stageGraph, logger)
            % PROVENANCEHASHER Constructs the hasher service.
            %   stageGraph: A fully constructed pipeline.StageGraph object.
            %   logger: An mlog.Logger instance for logging events and errors.
            obj.StageGraph = stageGraph;
            obj.CodeHashMap = containers.Map('KeyType', 'char', 'ValueType', 'char');
            obj.Logger = logger;
        end

        function provenanceHash = computeProvenanceHash(obj, task)
            % COMPUTEPROVENANCEHASH Calculates the final hash for a given task.
            %   task: A struct containing all information for the computation:
            %         - task.stage_name: The name of the stage.
            %         - task.parameters: The complete parameter struct for the run.
            %         - task.input_hashes: A struct mapping local input names
            %                            to the provenance hashes of their sources.

            % 1. Get the Code Hash for the stage's function.
            codeHash = obj.getStageCodeHash(task.stage_name);

            % 2. Get the Granular Parameter Hash for the stage's explicit params.
            paramHash = obj.getGranularParamHash(task.stage_name, task.parameters);

            % 3. Get the Input Hash from the combined hashes of all dependencies.
            inputHash = obj.getInputSetHash(task.input_hashes);

            % 4. Combine the three component hashes into a final struct.
            %    This "hash of hashes" is the definitive Provenance Hash.
            provenanceComponents = struct(...
                'code', codeHash, ...
                'params', paramHash, ...
                'inputs', inputHash ...
            );
            
            % Log the component hashes for debugging purposes
            obj.Logger.debug('pipeline:ProvenanceHasher:HashComponentComputed: Stage=%s, CodeHash=%s, ParamHash=%s, InputHash=%s', ...
                task.stage_name, codeHash, paramHash, inputHash);
            
            % The final hash is the hash of the deterministically sorted
            % components struct.
            provenanceHash = pipeline.utility.Hasher.hash_struct(provenanceComponents);
        end
    end

    methods (Access = private)
        function codeHash = getStageCodeHash(obj, stage_name)
            % Retrieves the Code Hash, using an in-memory cache to avoid
            % re-reading the same file multiple times during a run.
            if obj.CodeHashMap.isKey(stage_name)
                codeHash = obj.CodeHashMap(stage_name);
                obj.Logger.debug('pipeline:ProvenanceHasher:CodeHashCacheHit: Retrieved cached code hash for stage %s', stage_name);
                return;
            end

            stageConfig = obj.StageGraph.getStageConfig(stage_name);
            functionHandle = stageConfig.function;
            filePath = which(func2str(functionHandle));

            if isempty(filePath)
                msg = sprintf('Could not find the source file for the function in stage ''%s''.', stage_name);
                obj.Logger.fatal('pipeline:ProvenanceHasher:FunctionNotFound: %s', msg);
                error('pipeline:ProvenanceHasher:FunctionNotFound', msg);
            end

            codeHash = pipeline.utility.Hasher.hash_file(filePath);
            obj.CodeHashMap(stage_name) = codeHash; % Cache the result
            obj.Logger.debug('pipeline:ProvenanceHasher:CodeHashComputed: Computed and cached code hash for stage %s', stage_name);
        end

        function paramHash = getGranularParamHash(obj, stage_name, all_params)
            % Creates the hash from ONLY the parameters explicitly used by the stage.
            explicit_param_names = obj.StageGraph.getExplicitParams(stage_name);
            
            if isempty(explicit_param_names)
                % If a stage uses no parameters, its parameter hash is a
                % constant, deterministic hash of an empty struct.
                paramHash = pipeline.utility.Hasher.hash_struct(struct());
                return;
            end

            % Build a new struct containing only the explicit parameters.
            params_to_hash = struct();
            for i = 1:length(explicit_param_names)
                param_name = explicit_param_names{i};
                if isfield(all_params, param_name)
                    params_to_hash.(param_name) = all_params.(param_name);
                else
                    % This should ideally be caught by a validation step earlier.
                    msg = sprintf('Stage ''%s'' requires parameter ''%s'', which was not provided.', stage_name, param_name);
                    obj.Logger.fatal('pipeline:ProvenanceHasher:MissingParameter: %s', msg);
                    error('pipeline:ProvenanceHasher:MissingParameter', msg);
                end
            end
            
            paramHash = pipeline.utility.Hasher.hash_struct(params_to_hash);
        end

        function inputHash = getInputSetHash(~, input_hashes_struct)
            % Hashes the struct of input hashes. The hash_struct method
            % ensures this is deterministic by sorting the field names
            % (local input names) alphabetically.
            if isempty(fieldnames(input_hashes_struct))
                % For source stages with no inputs.
                inputHash = pipeline.utility.Hasher.hash_struct(struct());
                return;
            end
            
            inputHash = pipeline.utility.Hasher.hash_struct(input_hashes_struct);
        end
    end
end
