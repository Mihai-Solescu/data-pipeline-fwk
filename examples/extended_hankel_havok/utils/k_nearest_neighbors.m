function nearest_neighbors_idx = k_nearest_neighbors(X, p, k)
    % Finds the k nearest neighbors of point p in dataset X
    %
    % Inputs:
    %   X: Data points (each column is a point in space)
    %   p: Reference point to find neighbors for
    %   k: Number of nearest neighbors to find
    %
    % Outputs:
    %   nearest_neighbors: Indices of the k nearest neighbors in X

    arguments
        X (:, :) double % Data points (each column is a point in space)
        p (1, :) double % Reference point to find neighbors for
        k (1, 1) {mustBeInteger, mustBePositive} % Number of nearest neighbors to find
    end

    % Ensure dimensions
    [n, m] = size(X);

    if size(p) ~= size(X(1,:))
        error('Dimension mismatch: p must have same dimension as points in X');
    end
    
    % Compute distances from p to all points in X
    diff = X - p;
    distances = zeros(n,1);
    for i = 1:n
        distances(i) = norm(diff(i,:));
    end
    
    % Sort distances and get indices of the k nearest neighbors
    [~, idx] = sort(distances);
    size(idx);
    
    % Return indices of the k nearest neighbors
    nearest_neighbors_idx = idx(1:k);
end