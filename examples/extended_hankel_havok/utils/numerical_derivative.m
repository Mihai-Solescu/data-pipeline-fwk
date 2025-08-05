function dV = numerical_derivative(V, dt, options)
    % NUMERICAL_DERIVATIVE Computes the numerical derivative of a matrix using finite differences.
    % Inputs:
    %   V     - Input matrix (size: N x M, where N is the number of data points and M is the number of variables)
    %   dt    - Time step between consecutive data points
    %   options.num_points - Number of points to use for the derivative calculation (3, or 5, default: 5)
    %   options.compute_endpoints - Whether to compute derivatives at first and last points (default: false)
    %
    % Outputs:
    %   dV    - Matrix of numerical derivatives (size: N x M)
    
    arguments
        V (:, :) double % Input matrix
        dt (1,1) double {mustBePositive} % Time step
        options.num_points (1,1) double {mustBeInteger, mustBePositive} = 5 % Order of finite difference method
        options.compute_endpoints (1,1) logical = false % Whether to compute derivatives at endpoints
    end

    if options.compute_endpoints || (options.num_points ~= 3 && options.num_points ~= 5)
        error('Not implemented')
    end
    
    % Preallocate the output matrix
    dV = zeros(size(V));
    
    if options.num_points == 5 % || options.order == 4
        % Compute the derivative using 5-point central difference (4th order accurate)
        % Formula: f'(x) ≈ [f(x-2h) - 8f(x-h) + 8f(x+h) - f(x+2h)] / (12h)
        for i = 3:size(V, 1) - 2
            dV(i, :) = (V(i - 2, :) - 8 * V(i - 1, :) + 8 * V(i + 1, :) - V(i + 2, :)) / (12 * dt);
        end
    
    elseif options.num_points == 3 % || options.order == 2
        % Compute the derivative using 3-point central difference (2nd order accurate)
        % Formula: f'(x) ≈ [f(x+h) - f(x-h)] / (2h)
        for i = 2:size(V, 1) - 1
            dV(i, :) = (V(i + 1, :) - V(i - 1, :)) / (2 * dt);
        end
    end
end