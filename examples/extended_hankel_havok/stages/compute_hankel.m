function out = compute_hankel(in, p)

    xdat_filtered = in.master_timeseries(1:p.timeseries_length);
    t_filtered = in.time_vector(1:p.timeseries_length);

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