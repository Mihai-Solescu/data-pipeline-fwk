function [U,S,V,s,A,B,y,t] = pHAVOK_from_hankel(H,dt,r,lambda,options)
    % pHAVOK_from_hankel: HAVOK analysis starting from a pre-constructed Hankel matrix
    % 
    % This function implements the HAVOK algorithm starting from an existing Hankel matrix,
    % which decomposes chaotic system's dynamics into a linear model and a component 
    % representing intermittent forcing.
    %
    % Inputs:
    %   H        - Pre-constructed Hankel matrix (stackmax x N-stackmax+1)
    %   dt       - The time step of the original data
    %   r        - The number of singular vectors (modes) to retain for the
    %              regression model. This determines the rank of the identified
    %              linear system.
    %   lambda   - The sparsification threshold for the sequential least-squares
    %              regression. A non-zero value promotes a sparse model by
    %              eliminating small terms in the system matrix. Set to 0 for
    %              standard least-squares.
    %
    % Name-Value Pair Arguments:
    %   use_sinusoid - (Optional) Flag to include sinusoidal basis functions in
    %                  the library of nonlinear time series. Set to 1 to include,
    %                  0 (default) to exclude.
    %   polyorder - (Optional) Integer for the polynomial order of the library.
    %               Default is 1.
    %   max_harmonics - (Optional) Maximum harmonic number for sinusoidal terms.
    %                   Default is 10 (matching poolData behavior).
    %
    % Outputs:
    %   U - Left singular vectors of the Hankel matrix. These form an orthogonal
    %       basis for the patterns observed in the data.
    %   S - Singular values of the Hankel matrix. These indicate the energy
    %       or importance of each corresponding mode in U and V.
    %   V - Right singular vectors of the Hankel matrix (eigen-time delay
    %       coordinates). These represent the temporal evolution of the system's
    %       modes.
    %   A - The identified linear system matrix. This matrix models the linear
    %       part of the system's dynamics in the V coordinates (i.e., dv/dt = A*v).
    %   B - The identified forcing vector. This vector captures the influence of
    %       the forcing term (the r-th mode of V) on the linear dynamics.
    %   y - Reconstructed trajectory using the identified linear system.
    %   t - Time vector corresponding to the reconstructed trajectory.
    %
    % The core steps of the algorithm are:
    % 1. Take the pre-constructed Hankel matrix H as input.
    % 2. Compute the SVD of the Hankel matrix to obtain the U, S, and V matrices.
    % 3. Numerically differentiate the V matrix to obtain dV/dt.
    % 4. Use sparse regression (SINDy) to identify a linear model of the form
    %    dV/dt = A*V + B*v_r, where v_r is the r-th mode of V, which often
    %    acts as a forcing term.
    %
    % Example usage:
    %   % First create Hankel matrix from time series data
    %   [t, xdat] = lorenz_generate(0.01, 10);
    %   H = hankelize(xdat(:,1), 50);
    %   % Then apply HAVOK analysis
    %   [U,S,V,A,B,y,t] = pHAVOK_from_hankel(H, 0.01, 12, 0);

    arguments
        H                                                       % Pre-constructed Hankel matrix
        dt                                                      % Time step
        r                                                       % Number of modes to retain
        lambda                                                  % Sparsification threshold
        options.use_sinusoid (1,1) {mustBeNumericOrLogical} = 0
        options.polyorder (1,1) {mustBeInteger, mustBePositive} = 1
        options.max_harmonics (1,1) {mustBeInteger, mustBePositive} = 10
    end
    
    %% Input validation
    if isempty(H) || ~ismatrix(H)
        error('Input H must be a non-empty matrix');
    end
    
    if r > min(size(H))
        warning('Number of modes r (%d) is larger than matrix dimensions. Reducing to %d.', ...
            r, min(size(H)));
        r = min(size(H));
    end

    %% EIGEN-TIME DELAY COORDINATES
    % Input H is already the Hankel matrix, so proceed directly to SVD
    clear V, clear dV
    [U,S,V] = svd(H,'econ');
    s = diag(S); % singular values

    %% COMPUTE DERIVATIVES
    % compute derivative using numerical_derivative function with 5th order finite difference
    V_subset = V(:, 1:r);
    dV_full = numerical_derivative(V_subset, dt, 'num_points', 5);
    
    % Remove boundary points that may have lower accuracy due to finite difference approximation
    x = V(3:end-2, 1:r);
    dx = dV_full(3:end-2, :);

    %%  BUILD HAVOK REGRESSION MODEL ON TIME DELAY COORDINATES
    % This implementation uses the SINDY code, but least-squares works too
    % Build library of nonlinear time series
    [Theta_poly, ~] = polyorder_library(x, options.polyorder);
    Theta = Theta_poly;
    if options.use_sinusoid
        % Use sinusoid library if specified
        [Theta_sin, ~] = sinusoidal_library(x, 'nVars', r, 'max_harmonics', options.max_harmonics);
        Theta = [Theta, Theta_sin];
    end

    % normalize columns of Theta (required in new time-delay coords)
    normTheta = vecnorm(Theta);
    Theta = Theta ./ normTheta;

    % compute Sparse regression: sequential least squares
    % requires different lambda parameters for each column
    clear Xi
    for k=1:r-1
        Xi(:,k) = sparse_regression(Theta,dx(:,k),lambda);  % lambda = 0 gives better results 
    end
    
    % Denormalize
    for k=1:size(Xi,1)
        Xi(k,:) = Xi(k,:)/normTheta(k);
    end

    A = Xi(2:r+1,1:r-1)';
    B = A(:,r);
    A = A(:,1:r-1);

    % Reconstruction of the original attractor for the full trajectory
    % Use all available data points
    L = 1:size(x,1);
    sys = ss(A,B,eye(r-1),0*B);
    [y,t] = lsim(sys,x(L,r),dt*(L-1),x(1,1:r-1));
end