function [t, xdat] = chua_generate(dt, t_end, x0, alpha, beta, m0, m1)
%CHUA_GENERATE Generates time series data from Chua's circuit.
%
%   [t, xdat] = chua_generate(dt, t_end, x0, alpha, beta, m0, m1)
%
%   This function simulates Chua's circuit, a simple electronic circuit that
%   exhibits chaotic behavior, famously producing the "double scroll" attractor.
%
%   Inputs:
%   - dt: Time step for the output data.
%   - t_end: Total simulation time.
%   - x0 (optional): Initial condition vector [x; y; z]. 
%     Default is [0.7; 0; 0].
%   - alpha (optional): System parameter. Default is 15.6.
%   - beta (optional): System parameter. Default is 28.
%   - m0 (optional): System parameter for the piecewise-linear component. 
%     Default is -8/7.
%   - m1 (optional): System parameter for the piecewise-linear component. 
%     Default is -5/7.
%
%   Outputs:
%   - t: A column vector of time points.
%   - xdat: A matrix where each row corresponds to the state [x, y, z] at a
%     given time point.

    % --- Set Default Parameters ---
    if nargin < 7, m1 = -5/7; end
    if nargin < 6, m0 = -8/7; end
    if nargin < 5, beta = 28; end
    if nargin < 4, alpha = 15.6; end
    if nargin < 3, x0 = [0.7; 0; 0]; end

    % --- Define the nonlinear component and its derivative ---
    h = @(x) m1*x + 0.5*(m0-m1)*(abs(x+1) - abs(x-1));
    % The derivative of h(x) is piecewise constant
    h_prime = @(x) (x < -1 | x > 1) * m1 + (x >= -1 & x <= 1) * m0;

    % --- Define Chua's System ODE ---
    chua_ode = @(t, v) [alpha * (v(2) - h(v(1)));
                         v(1) - v(2) + v(3);
                         -beta * v(2)];

    % --- Define the Jacobian Matrix ---
    % Providing the analytical Jacobian helps the stiff solver converge.
    jacobian = @(t, v) [-alpha * h_prime(v(1)), alpha, 0;
                         1,                      -1,    1;
                         0,                      -beta, 0];

    % --- Solve the ODE ---
    t_span = [0, t_end];
    % Pass the Jacobian to the solver
    options = odeset('RelTol', 1e-6, 'AbsTol', 1e-9, 'Jacobian', jacobian);
    
    % Using a different stiff solver (ode23t) may be more robust here
    [t_sol, x_sol] = ode23t(chua_ode, t_span, x0, options);

    % --- Interpolate to a fixed time step dt ---
    t = (0:dt:t_end)';
    xdat = interp1(t_sol, x_sol, t, 'spline');

end
