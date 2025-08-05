function Xi = sparse_regression(Theta, dXdt, lambda, n, options)
    % SPARSE_REGRESSION Performs sparse regression for system identification
    % using sequential thresholded least-squares algorithm (STRidge)
    %
    % INPUTS:
    %   Theta  - Library of candidate functions evaluated at data points 
    %   n      - Maximum number of iterations (default: 10)
    %
    % OUTPUT:
    %   Xi     - Sparse coefficient matrix that defines the identified system dynamics
    %
    % Example usage:
    %   Xi = sparse_regression(Theta, dXdt, 0.1, 20);
    
    arguments
        Theta double   % Library of candidate functions
        dXdt double    % Time derivatives
        lambda double  % Sparsification parameter
        n double       % Number of dimensions
        options.max_iterations double = 10  % Maximum number of iterations
    end

    % Copyright 2015, All Rights Reserved
    % Code by Steven L. Brunton
    % For Paper, "Discovering Governing Equations from Data: 
    %        Sparse Identification of Nonlinear Dynamical Systems"
    % by S. L. Brunton, J. L. Proctor, and J. N. Kutz
    
    % compute Sparse regression: sequential least squares
    Xi = Theta\dXdt;  % initial guess: Least-squares

    % lambda is our sparsification knob.
    for k = 1:options.max_iterations
        smallinds = (abs(Xi)<lambda);   % find small coefficients
        Xi(smallinds)=0;                % and threshold
        for ind = 1:n                   % n is state dimension
            biginds = ~smallinds(:,ind);
            % Regress dynamics onto remaining terms to find sparse Xi
            Xi(biginds,ind) = Theta(:,biginds)\dXdt(:,ind); 
        end
    end
end