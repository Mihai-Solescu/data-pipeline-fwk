function out = compute_svd(in, p)

    [U, S, V] = svd(in.H, 'econ');

    % Truncate SVD if truncation rank is specified
    if isfield(p, 'truncation_rank') && p.truncation_rank < min(size(S))
        U = U(:, 1:p.truncation_rank);
        S = S(1:p.truncation_rank, 1:p.truncation_rank);
        V = V(:, 1:p.truncation_rank);
    end

    out.U = U;
    out.S = S;
    out.V = V;
    out.singular_values = diag(S);
end