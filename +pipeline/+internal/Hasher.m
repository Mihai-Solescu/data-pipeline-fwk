% +storage-manager/Hasher.m
classdef Hasher
    % Hasher Provides static methods for creating consistent SHA-256 hashes.
    % This utility is central to the framework's caching and reproducibility
    % by providing a deterministic way to fingerprint files, data, and structs.

    methods (Static)

        function sha256_hash = hash_file(filePath)
            % hash_file Computes the SHA-256 hash of a file's raw bytes.
            % Motivation: This is used to create the Code Hash for a stage's
            % component function. Reading raw bytes ensures that any change,
            % including line endings, is detected. It guarantees that the
            % exact same file content will always produce the same hash.

            try
                % Get the Java MessageDigest instance for SHA-256
                md = java.security.MessageDigest.getInstance('SHA-256');

                % Read the entire file into a raw byte array
                fid = fopen(filePath, 'rb');
                if fid == -1
                    error('Hasher:FileError', 'Could not open file: %s', filePath);
                end
                bytes = fread(fid, '*uint8');
                fclose(fid);

                % Update the digest with the file bytes and get the hash
                hash_bytes = md.digest(bytes);

                % Convert the hash bytes to a lowercase hexadecimal string
                sha256_hash = lower(sprintf('%02x', typecast(hash_bytes, 'uint8')));
            catch ME
                % Re-throw file errors as-is, but wrap other errors as JavaError
                if strcmp(ME.identifier, 'Hasher:FileError')
                    rethrow(ME);
                else
                    error('Hasher:JavaError', 'Failed to compute hash for file %s. Details: %s', ...
                          filePath, ME.message);
                end
            end
        end

        function sha256_hash = hash_data(data)
            % hash_data Computes the SHA-256 hash of any MATLAB variable.
            % Motivation: This is the core function for hashing parameters
            % or any other data. It uses MATLAB's `getByteStreamFromArray`
            % for a standardized conversion to a byte stream, which is then
            % hashed. This ensures that the same data structure always
            % results in the same hash.

            try
                % Get the Java MessageDigest instance for SHA-256
                md = java.security.MessageDigest.getInstance('SHA-256');

                % Convert the MATLAB variable to a standardized byte stream
                bytes = getByteStreamFromArray(data);

                % Update the digest and get the hash
                hash_bytes = md.digest(bytes);

                % Convert to a lowercase hexadecimal string
                sha256_hash = lower(sprintf('%02x', typecast(hash_bytes, 'uint8')));
            catch ME
                error('Hasher:DataHashError', 'Failed to compute hash for data. Details: %s', ...
                      ME.message);
            end
        end

        function sha256_hash = hash_struct(s)
            % hash_struct Computes a deterministic hash for a struct.
            % Motivation: Hashing a struct directly is not deterministic
            % because the field order can vary. This method solves that
            % problem by first sorting the field names alphabetically. It
            % then creates a new struct with the sorted fields, ensuring
            % that structs with the same fields and values always produce
            % the same hash, regardless of their original construction.
            % This is critical for granular parameter hashing.

            if ~isstruct(s)
                error('Hasher:InputError', 'Input must be a struct.');
            end

            % Get field names and sort them alphabetically
            fields = fieldnames(s);
            sorted_fields = sort(fields);

            % Create a new struct with fields in sorted order
            sorted_struct = struct();
            for i = 1:length(sorted_fields)
                field_name = sorted_fields{i};
                sorted_struct.(field_name) = s.(field_name);
            end

            % Hash the deterministically ordered struct
            sha256_hash = pipeline.internal.Hasher.hash_data(sorted_struct);
        end

    end
end
