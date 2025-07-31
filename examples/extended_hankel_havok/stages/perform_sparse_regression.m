function out = perform_sparse_regression(in, p)

    normTheta = vecnorm(in.Theta);
    Theta_norm = in.Theta ./ normTheta;
    
    warning('off', 'MATLAB:rankDeficientMatrix');
    warning('off', 'MATLAB:nearlySingularMatrix');

    % Column-wise regression for HAVOK
    Xi_norm = zeros(size(Theta_norm, 2), p.truncation_rank - 1);
    for k = 1:(p.truncation_rank - 1)
        Xi_norm(:, k) = sparse_regression(Theta_norm, in.dVdt(:, k), 0, 1); % lambda = 0 for basic HAVOK
    end

    % Denormalize
    out.Xi = Xi_norm ./ normTheta';

    % Extract A and B matrices
    out.A = out.Xi(2:r_actual+1, :)';
    out.B = out.A(:, end);
    out.A = out.A(:, 1:end-1);

end