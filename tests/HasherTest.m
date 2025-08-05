classdef HasherTest < matlab.unittest.TestCase
    % HasherTest Unit tests for the Hasher utility class
    % This test file validates the three core methods of the Hasher class:
    % hash_file, hash_data, and hash_struct according to TDD requirements.
    
    properties (TestParameter)
    % Test data for various MATLAB types
    test_data = {42, ...                   % double scalar
                 'hello', ...              % char array
                 [1, 2, 3], ...            % double vector
                 struct('a', 1, 'b', 2), ...% struct
                 true, ...                 % logical
                 NaN, ...                  % special numeric
                 Inf, ...                  % special numeric
                 [], ...                   % empty double
                 {}, ...                   % empty cell
                 'test string', ...        % string array
                 complex(1, 2)}            % complex number
    end
    
    properties
        tempDir
    end
    
    methods (TestMethodSetup)
        function setup(testCase)
            % Create temporary directory for test files
            testCase.tempDir = tempname;
            mkdir(testCase.tempDir);
        end
    end
    
    methods (TestMethodTeardown)
        function teardown(testCase)
            % Clean up temporary directory
            if ~isempty(testCase.tempDir) && exist(testCase.tempDir, 'dir')
                rmdir(testCase.tempDir, 's');
            end
        end
    end
    
    methods (Test)
        
        function test_hash_file_identical_files(testCase)
            % Test that identical files produce identical hashes
            
            % Create two identical files
            content = 'This is test content for hashing.';
            file1 = fullfile(testCase.tempDir, 'file1.txt');
            file2 = fullfile(testCase.tempDir, 'file2.txt');
            
            % Write identical content to both files
            fid1 = fopen(file1, 'w');
            fprintf(fid1, '%s', content);
            fclose(fid1);
            
            fid2 = fopen(file2, 'w');
            fprintf(fid2, '%s', content);
            fclose(fid2);
            
            % Compute hashes
            hash1 = pipeline.utility.Hasher.hash_file(file1);
            hash2 = pipeline.utility.Hasher.hash_file(file2);
            
            % Assert that identical files have identical hashes
            testCase.verifyEqual(hash1, hash2, ...
                'Identical files should produce identical hashes');
        end
        
        function test_hash_file_different_files(testCase)
            % Test that different files produce different hashes
            
            % Create two different files
            file1 = fullfile(testCase.tempDir, 'file1.txt');
            file2 = fullfile(testCase.tempDir, 'file2.txt');
            
            % Write different content to each file
            fid1 = fopen(file1, 'w');
            fprintf(fid1, 'Content A');
            fclose(fid1);
            
            fid2 = fopen(file2, 'w');
            fprintf(fid2, 'Content B');
            fclose(fid2);
            
            % Compute hashes
            hash1 = pipeline.utility.Hasher.hash_file(file1);
            hash2 = pipeline.utility.Hasher.hash_file(file2);
            
            % Assert that different files have different hashes
            testCase.verifyNotEqual(hash1, hash2, ...
                'Different files should produce different hashes');
        end
        
        function test_hash_file_known_content(testCase)
            % Test that a known file content matches a pre-computed SHA-256 hash
            
            % Create a file with known content
            knownContent = 'hello world';
            testFile = fullfile(testCase.tempDir, 'known.txt');
            
            fid = fopen(testFile, 'w');
            fprintf(fid, '%s', knownContent);
            fclose(fid);
            
            % Pre-computed SHA-256 hash for "hello world" (without newline)
            expectedHash = 'b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9';
            
            % Compute hash using our function
            actualHash = pipeline.utility.Hasher.hash_file(testFile);
            
            % Assert that the hash matches the expected value
            testCase.verifyEqual(actualHash, expectedHash, ...
                'Hash of known content should match pre-computed value');
        end
        
        function test_hash_file_nonexistent_file(testCase)
            % Test that hashing a non-existent file throws an error
            
            nonexistentFile = fullfile(testCase.tempDir, 'nonexistent.txt');
            
            % Assert that an error is thrown
            testCase.verifyError(@() pipeline.utility.Hasher.hash_file(nonexistentFile), ...
                'pipeline:Hasher:FileError', ...
                'Should throw FileError for non-existent file');
        end
        
        function test_hash_data_identical_data(testCase, test_data)
            % Test that identical data produces identical hashes
            
            % Hash the same data twice
            hash1 = pipeline.utility.Hasher.hash_data(test_data);
            hash2 = pipeline.utility.Hasher.hash_data(test_data);
            
            % Assert that identical data produces identical hashes
            testCase.verifyEqual(hash1, hash2, ...
                'Identical data should produce identical hashes');
        end
        
        function test_hash_data_different_types(testCase)
            % Test that different data types produce different hashes
            
            % Create different data
            data1 = 42;
            data2 = '42';
            data3 = [4, 2];
            
            % Compute hashes
            hash1 = pipeline.utility.Hasher.hash_data(data1);
            hash2 = pipeline.utility.Hasher.hash_data(data2);
            hash3 = pipeline.utility.Hasher.hash_data(data3);
            
            % Assert that all hashes are different
            testCase.verifyNotEqual(hash1, hash2, ...
                'Different data types should produce different hashes');
            testCase.verifyNotEqual(hash1, hash3, ...
                'Different data types should produce different hashes');
            testCase.verifyNotEqual(hash2, hash3, ...
                'Different data types should produce different hashes');
        end
        
        function test_hash_data_deterministic(testCase)
            % Test that the same data always produces the same hash
            
            % Create a complex data structure
            complexData = struct('numbers', [1, 2, 3], ...
                                'text', 'hello', ...
                                'nested', struct('a', 1, 'b', 2));
            
            % Hash multiple times
            hashes = cell(5, 1);
            for i = 1:5
                hashes{i} = pipeline.utility.Hasher.hash_data(complexData);
            end
            
            % Assert all hashes are identical
            for i = 2:5
                testCase.verifyEqual(hashes{1}, hashes{i}, ...
                    'The same data should always produce the same hash');
            end
        end
        
        function test_hash_struct_field_order_independence(testCase)
            % Test that structs with same fields and values but different order produce same hash
            
            % Create two structs with the same fields and values but in different order
            struct1 = struct();
            struct1.field_a = 'value_a';
            struct1.field_b = 42;
            struct1.field_c = [1, 2, 3];
            
            struct2 = struct();
            struct2.field_c = [1, 2, 3];
            struct2.field_a = 'value_a';
            struct2.field_b = 42;
            
            % Compute hashes
            hash1 = pipeline.utility.Hasher.hash_struct(struct1);
            hash2 = pipeline.utility.Hasher.hash_struct(struct2);
            
            % Assert that both structs produce the same hash
            testCase.verifyEqual(hash1, hash2, ...
                'Structs with same fields and values should produce same hash regardless of field order');
        end
        
        function test_hash_struct_different_values(testCase)
            % Test that structs with different values produce different hashes
            
            % Create two structs with same fields but different values
            struct1 = struct('field_a', 'value1', 'field_b', 42);
            struct2 = struct('field_a', 'value2', 'field_b', 42);
            
            % Compute hashes
            hash1 = pipeline.utility.Hasher.hash_struct(struct1);
            hash2 = pipeline.utility.Hasher.hash_struct(struct2);
            
            % Assert that structs with different values have different hashes
            testCase.verifyNotEqual(hash1, hash2, ...
                'Structs with different values should produce different hashes');
        end
        
        function test_hash_struct_different_fields(testCase)
            % Test that structs with different fields produce different hashes
            
            % Create two structs with different fields
            struct1 = struct('field_a', 'value', 'field_b', 42);
            struct2 = struct('field_a', 'value', 'field_c', 42);
            
            % Compute hashes
            hash1 = pipeline.utility.Hasher.hash_struct(struct1);
            hash2 = pipeline.utility.Hasher.hash_struct(struct2);
            
            % Assert that structs with different fields have different hashes
            testCase.verifyNotEqual(hash1, hash2, ...
                'Structs with different fields should produce different hashes');
        end
        
        function test_hash_struct_non_struct_input(testCase)
            % Test that passing non-struct input throws an error
            
            % Test with various non-struct inputs
            nonStructInputs = {42, 'hello', [1, 2, 3], {1, 2, 3}};
            
            for i = 1:length(nonStructInputs)
                testCase.verifyError(@() pipeline.utility.Hasher.hash_struct(nonStructInputs{i}), ...
                    'pipeline:Hasher:InputError', ...
                    'Should throw InputError for non-struct input');
            end
        end
        
        function test_hash_struct_empty_struct(testCase)
            % Test that empty structs can be hashed
            
            emptyStruct = struct();
            
            % This should not throw an error
            hash = pipeline.utility.Hasher.hash_struct(emptyStruct);
            
            % Verify the result is a non-empty string
            testCase.verifyClass(hash, 'char', 'Hash should be a character array');
            testCase.verifyNotEmpty(hash, 'Hash should not be empty');
            
            % Verify it's a valid hex string of appropriate length (SHA-256 = 64 chars)
            testCase.verifyEqual(length(hash), 64, 'SHA-256 hash should be 64 characters long');
            testCase.verifyMatches(hash, '^[a-f0-9]+$', 'Hash should be lowercase hexadecimal');
        end
        
        function test_hash_struct_nested_struct(testCase)
            % Test that nested structs can be hashed deterministically
            
            % Create a struct with nested structs
            nestedStruct = struct();
            nestedStruct.level1_a = struct('nested_field', 'value1');
            nestedStruct.level1_b = 42;
            nestedStruct.level1_c = struct('deeply', struct('nested', 'value2'));
            
            % Hash multiple times
            hash1 = pipeline.utility.Hasher.hash_struct(nestedStruct);
            hash2 = pipeline.utility.Hasher.hash_struct(nestedStruct);
            
            % Assert consistency
            testCase.verifyEqual(hash1, hash2, ...
                'Nested structs should produce consistent hashes');
        end
        
        function test_hash_file_binary_content(testCase)
            % Test that binary files can be hashed
            binContent = uint8([1 2 10 255 0 13]);
            testFile = fullfile(testCase.tempDir, 'test.bin');
            
            fid = fopen(testFile, 'wb');
            fwrite(fid, binContent, 'uint8');
            fclose(fid);
            
            hash1 = pipeline.utility.Hasher.hash_file(testFile);
            hash2 = pipeline.utility.Hasher.hash_file(testFile);
            
            testCase.verifyNotEmpty(hash1);
            testCase.verifyEqual(hash1, hash2, 'Binary file hashing should be deterministic.');
        end
    end
end
