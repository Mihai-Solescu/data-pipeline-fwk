function [t, xdat] = rikitake_generate(dt, t_end, x0, mu, A)
%RIKITAKE_GENERATE Generates time series data from the Rikitake dynamo system.
%
%   Paper: "Global dynamics of the Rikitake system", Jaume Llibre, Marcelo Messias, 2009
%
%   [t, xdat] = rikitake_generate(dt, t_end, x0, mu, A)
%
%   This function simulates the Rikitake two-disk dynamo system, which is a model
%   used in geophysics to study the Earth's magnetic field reversals.
%
%   Inputs:
%   - dt: Time step for the output data.
%   - t_end: Total simulation time.
%   - x0 (optional): Initial condition vector [x; y; z]. 
%     Default is [1; 0; 0].
%   - mu (optional): A parameter of the system. Default is 2.0.
%   - A (optional): A parameter of the system. Default is 5.0.
%
%   Outputs:
%   - t: A column vector of time points.
%   - xdat: A matrix where each row corresponds to the state [x, y, z] at a
%     given time point.

    % --- Set Default Parameters ---
    if nargin < 5, A = 5.0; end
    if nargin < 4, mu = 2.0; end
    if nargin < 3, x0 = [1; 0; 0]; end

    % --- Define the Rikitake System ODE ---
    rikitake_ode = @(t, x) [-mu * x(1) + x(3) * x(2);
                             -mu * x(2) + x(1) * (x(3) - A);
                             1 - x(1) * x(2)];

    % --- Solve the ODE ---
    t_span = [0, t_end];
    options = odeset('RelTol', 1e-6, 'AbsTol', 1e-9);
    
    [t_sol, x_sol] = ode45(rikitake_ode, t_span, x0, options);

    % --- Interpolate to a fixed time step dt ---
    t = (0:dt:t_end)';
    xdat = interp1(t_sol, x_sol, t, 'spline');

end
