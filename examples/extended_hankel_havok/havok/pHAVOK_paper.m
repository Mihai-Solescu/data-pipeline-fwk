function [U,S,V,s,A,B] = pHAVOK_paper(xdat,dt,stackmax,r,lambda,options)
    % pHAVOK: Hankel Alternative View of Koopman analysis for system identification.
    %
    % This function implements the HAVOK algorithm, which decomposes a chaotic
    % system's dynamics into a linear model and a component representing
    % intermittent forcing. It is particularly useful for identifying the
    % underlying structure of chaotic systems from time-series data.
    %
    % Inputs:
    %   xdat     - Time-series data, where each row is a time step and each
    %              column is a variable.
    %   dt       - The time step of the data.
    %   stackmax - The number of time-shifted rows to stack in the Hankel matrix.
    %              This is equivalent to the embedding dimension.
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
    %
    % The core steps of the algorithm are:
    % 1. Construct a time-delay embedded Hankel matrix from the input data.
    % 2. Compute the SVD of the Hankel matrix to obtain the U, S, and V matrices.
    % 3. Numerically differentiate the V matrix to obtain dV/dt.
    % 4. Use sparse regression (SINDy) to identify a linear model of the form
    %    dV/dt = A*V + B*v_r, where v_r is the r-th mode of V, which often
    %    acts as a forcing term.

    arguments
        xdat
        dt
        stackmax
        r
        lambda
        options.use_sinusoid (1,1) {mustBeNumericOrLogical} = 0
        options.polyorder (1,1) {mustBeInteger, mustBePositive} = 1
    end

    %% EIGEN-TIME DELAY COORDINATES
    clear V, clear dV, clear H
    H = zeros(stackmax,size(xdat,1)-stackmax);
    for k=1:stackmax
        H(k,:) = xdat(k:end-stackmax-1+k,1);
    end
    [U,S,V] = svd(H,'econ');
    s = diag(S); % singular values

    %% COMPUTE DERIVATIVES
    % compute derivative using fourth order central difference
    % use TVRegDiff if more error 
    dV = zeros(length(V)-5,r);
    for i=3:length(V)-3
        for k=1:r
            dV(i-2,k) = (1/(12*dt))*(-V(i+2,k)+8*V(i+1,k)-8*V(i-1,k)+V(i-2,k));
        end
    end  
    % concatenate
    x = V(3:end-3,1:r);
    dx = dV;

    %%  BUILD HAVOK REGRESSION MODEL ON TIME DELAY COORDINATES
    % This implementation uses the SINDY code, but least-squares works too
    % Build library of nonlinear time series
    Theta = poolData(x,r,options.polyorder,options.use_sinusoid);
    
    % normalize columns of Theta (required in new time-delay coords)
    for k=1:size(Theta,2)
        normTheta(k) = norm(Theta(:,k));
        Theta(:,k) = Theta(:,k)/normTheta(k);
    end 
    
    % compute Sparse regression: sequential least squares
    % requires different lambda parameters for each column
    clear Xi
    for k=1:r-1
        Xi(:,k) = sparsifyDynamics(Theta,dx(:,k),lambda*k,1);  % lambda = 0 gives better results 
    end
    
    % Build Theta again for denormalization (as in reference)
    Theta_orig = poolData(x,r,options.polyorder,options.use_sinusoid);
    for k=1:length(Xi)
        Xi(k,:) = Xi(k,:)/normTheta(k);
    end

    A = Xi(2:r+1,1:r-1)';
    B = A(:,r);
    A = A(:,1:r-1);
    %
    % L = 1:50000;
    % sys = ss(A,B,eye(r-1),0*B);
    % [y,t] = lsim(sys,x(L,r),dt*(L-1),x(1,1:r-1));
end