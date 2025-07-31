function out = compute_hankel(in, p)

    % Mapping from variable combination strings to column indices
    variable_map = containers.Map(...
        {'x', 'y', 'z', 'xy', 'xz', 'yz', 'xyz'}, ...
        {[1], [2], [3], [1,2], [1,3], [2,3], [1,2,3]});

    xdat_filtered = in.master_timeseries(1:p.timeseries_length);
    xdat_filtered = xdat_filtered(variable_map(p.variable_combination));
    % t_filtered = in.time_vector(1:p.timeseries_length); % unused

    switch p.hankel_type
        case 'normal'
            out.H = extended_hankelize(xdat_filtered, p.embedding_dim_multiple, 'row_index_delay', p.index_delay, 'col_index_delay', p.index_delay);
        case 'vertical'
            out.H = vertical_hankel(xdat_filtered, p.embedding_dim_multiple, 'index_delay', p.index_delay, 'max_degree', p.max_degree, 'max_harmonics', p.max_harmonics);
        case 'horizontal'
            out.H = horizontal_hankel(xdat_filtered, p.embedding_dim_multiple, 'index_delay', p.index_delay, 'max_degree', p.max_degree, 'max_harmonics', p.max_harmonics);
        case 'block_vertical'
            out.H = block_vertical_hankel(xdat_filtered, p.embedding_dim_multiple, 'index_delay', p.index_delay, 'max_degree', p.max_degree, 'max_harmonics', p.max_harmonics);
        otherwise
            error('Unknown Hankel type: %s', p.hankel_type);
    end

end