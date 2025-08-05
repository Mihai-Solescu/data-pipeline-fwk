function print_hdf5_structure(filename, options)
% PRINT_HDF5_STRUCTURE Displays the hierarchical structure of an HDF5 file.
%
%   This function provides a read-only inspection of an HDF5 file,
%   printing its complete internal structure (groups and datasets) in a
%   tree-like format to the command window.
%
%   USAGE:
%       print_hdf5_structure('my_results.h5');
%       print_hdf5_structure('my_results.h5', struct('output_to_file', 'structure.txt'));
%
%   INPUTS:
%       filename (string) - The path to the HDF5 file.
%       options.output_to_file (string, optional) - If provided, output is written to this file instead of the command window.
%
%   OUTPUTS:
%       None. The function prints directly to the command window.


    arguments
        filename (1,:) char;
        options.output_to_file (1,:) char = '';
    end
    output_file = options.output_to_file;

    % --- Input Validation ---
    if ~exist(filename, 'file')
        error('File not found: %s', filename);
    end

    % Setup output destination
    if ~isempty(output_file)
        fid = fopen(output_file, 'w');
        if fid == -1
            error('Could not open file for writing: %s', output_file);
        end
        outfun = @(varargin) fprintf(fid, varargin{:});
        cleanupObj = onCleanup(@() fclose(fid));
    else
        outfun = @fprintf;
    end

    outfun('Structure of HDF5 file: %s\n', filename);

    % --- Main Logic ---
    try
        % Get the complete metadata structure of the HDF5 file's root
        info = h5info(filename, '/');
        
        % Start the recursive traversal from the root
        outfun('/ (Root Group)\n');
        recursive_display(info, '', outfun);
        
    catch ME
        error('Failed to read HDF5 file structure: %s', ME.message);
    end

end


function recursive_display(group_info, prefix, outfun)
% RECURSIVE_DISPLAY Traverses and prints nodes (groups/datasets) in the HDF5 tree.

    % Get the number of groups and datasets at the current level
    num_groups = length(group_info.Groups);
    num_datasets = length(group_info.Datasets);
    total_items = num_groups + num_datasets;

    % --- 1. Process all subgroups at this level ---
    for i = 1:num_groups
        is_last_item = (i == total_items);
        % Determine the appropriate prefix for the current line and for its children
        if is_last_item
            branch_prefix = '`-- ';
            child_prefix = [prefix, '    ']; % No vertical line for children
        else
            branch_prefix = '|-- ';
            child_prefix = [prefix, '|   ']; % Vertical line for children
        end
        current_group = group_info.Groups(i);
        [~, group_name, ~] = fileparts(current_group.Name);
        % Print the group line
        outfun('%s%s[G] %s\n', prefix, branch_prefix, group_name);
        % Make the recursive call to display the contents of this subgroup
        recursive_display(current_group, child_prefix, outfun);
    end

    % --- 2. Process all datasets at this level ---
    for i = 1:num_datasets
        is_last_item = ((num_groups + i) == total_items);
        % Determine the appropriate prefix for the current dataset line
        if is_last_item
            branch_prefix = '`-- ';
        else
            branch_prefix = '|-- ';
        end
        current_dataset = group_info.Datasets(i);
        % Format the dataset size for display
        if isempty(current_dataset.Dataspace.Size)
            size_str = '[scalar]';
        else
            size_str = ['[' strjoin(arrayfun(@num2str, current_dataset.Dataspace.Size, 'UniformOutput', false), 'x') ']'];
        end
        % Get the datatype
        % For compound types, just show 'compound'. For others, show the class.
        if isstruct(current_dataset.Datatype) && isfield(current_dataset.Datatype, 'Class')
            if strcmp(current_dataset.Datatype.Class, 'H5T_COMPOUND')
                datatype_str = 'compound';
            else
                datatype_str = current_dataset.Datatype.Class;
            end
        elseif isfield(current_dataset.Datatype, 'Type')
            datatype_str = current_dataset.Datatype.Type;
        else
            datatype_str = 'unknown';
        end
        % Print the dataset line
        outfun('%s%s[D] %s: %s (%s)\n', prefix, branch_prefix, current_dataset.Name, size_str, datatype_str);
    end
end