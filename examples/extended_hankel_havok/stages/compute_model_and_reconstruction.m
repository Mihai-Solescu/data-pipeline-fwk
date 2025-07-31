function out = compute_model_and_reconstruction(in, p)

    % Extract forcing term (r-th right singular vector)
    out.forcing_term = in.V(:, p.truncation_rank);

    % Compute eigenvalues of identified model
    out.model_eigenvalues = eig(in.A);

    % Reconstruction
    out.y = in.U(:, 1:p.truncation_rank) * in.S(1:p.truncation_rank, 1:p.truncation_rank) * in.V(:, 1:p.truncation_rank)';
    out.t_recon = in.dt * (0:size(out.y,1)-1)';

end