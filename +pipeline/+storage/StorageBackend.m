classdef (Abstract) StorageBackend < handle
    % STORAGEBACKEND Abstract interface for persistent storage operations
    % This class defines the contract that all storage backends must
    % implement for the pipeline framework's L2 persistent storage.
    %
    % All concrete implementations must provide:
    %   - save(key, data): Store data with the given key
    %   - load(key): Retrieve data for the given key
    %   - exists(key): Check if data exists for the given key
    %   - delete(key): Remove data for the given key
    %
    % Error Handling:
    %   - All methods should throw appropriate errors for invalid operations
    %   - Missing keys should throw 'StorageBackend:KeyNotFound'
    %   - File I/O errors should be propagated appropriately
    %
    % See Also: pipeline.storage.HDF5Backend, pipeline.storage.StorageManager
    
    % Copyright 2025 The Framework Authors
    
    methods (Abstract)
        
        save(obj, key, data)
        % SAVE Store data with the given key
        %
        % Syntax:
        %   save(backend, key, data)
        %
        % Inputs:
        %   key  - String or char array, unique identifier for the data
        %   data - Any MATLAB data to be stored
        %
        % Throws:
        %   - 'StorageBackend:SaveFailed' if the save operation fails
        %   - 'StorageBackend:InvalidKey' if the key is invalid
        
        data = load(obj, key)
        % LOAD Retrieve data for the given key
        %
        % Syntax:
        %   data = load(backend, key)
        %
        % Inputs:
        %   key - String or char array, unique identifier for the data
        %
        % Outputs:
        %   data - The stored MATLAB data
        %
        % Throws:
        %   - 'StorageBackend:KeyNotFound' if the key does not exist
        %   - 'StorageBackend:LoadFailed' if the load operation fails
        
        tf = exists(obj, key)
        % EXISTS Check if data exists for the given key
        %
        % Syntax:
        %   tf = exists(backend, key)
        %
        % Inputs:
        %   key - String or char array, unique identifier for the data
        %
        % Outputs:
        %   tf - Logical, true if the key exists, false otherwise
        
        delete(obj, key)
        % DELETE Remove data for the given key
        %
        % Syntax:
        %   delete(backend, key)
        %
        % Inputs:
        %   key - String or char array, unique identifier for the data
        %
        % Throws:
        %   - 'StorageBackend:KeyNotFound' if the key does not exist
        %   - 'StorageBackend:DeleteFailed' if the delete operation fails
        
    end
    
end
