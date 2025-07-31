function out = construct_regression_library(in, p)

    [out.Theta, ~] = polyorder_library(in.V, p.library_max_degrees);
    if p.library_max_harmonics > 0
        [Theta_sin, ~] = sinusoidal_library(in.V, 'nVars', p.truncation_rank, 'max_harmonics', p.library_max_harmonics);
        out.Theta = [out.Theta, Theta_sin];
    end

end

