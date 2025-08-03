classdef (Abstract) IStorageBackend < handle
    %ISTORAGEBACKEND Defines the contract for all storage backends.
    %   This abstract class ensures that any storage implementation 
    %   (e.g., in-memory, HDF5) can be used interchangeably by the 
    %   framework's higher-level components.

    methods (Abstract)
        
        % WRITE Persists data for a given key.
        %
        % Inputs:
        %   key  - (char) A unique identifier for the data.
        %   data - (any) The MATLAB variable to be stored.
        write(obj, key, data);

        % READ Retrieves data for a given key.
        %
        % Inputs:
        %   key - (char) The unique identifier for the data.
        %
        % Returns:
        %   The stored MATLAB data. Throws an error if the key is not found.
        data = read(obj, key);

        % EXISTS Checks if a key exists in the backend.
        %
        % Inputs:
        %   key - (char) The unique identifier for the data.
        %
        % Returns:
        %   (logical) True if the key exists, otherwise false.
        flag = exists(obj, key);

        % REMOVE Removes data associated with a given key.
        %
        % Inputs:
        %   key - (char) The unique identifier for the data to be removed.
        remove(obj, key);
        
    end
end