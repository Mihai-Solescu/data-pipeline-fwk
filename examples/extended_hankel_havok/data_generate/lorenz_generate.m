function [t,xdat] = lorenz_generate(dt, final_time, options)
    % LORENZ_GENERATE Generates Lorenz system data using the ODE45 solver.
    %
    % INPUTS:
    %   dt         - Time step for integration (scalar)
    %   final_time - Final time for integration (scalar)
    %   options    - Options for ODE solver (struct, optional)
    %
    % OUTPUTS:
    %   t         - Time vector (column vector)
    %   xdat      - Data matrix (matrix of size N x 3, where N is the number of time steps)
    %
    % Example usage:
    %   dt = 0.001;
    %   final_time = 100;
    %   [t, xdat] = lorenz_generate(dt, final_time, ');   

    arguments
        dt (1,1) double {mustBePositive} = 0.001; % Time step for integration
        final_time (1,1) double {mustBePositive} = 100; % Final time for integration
        options.x0 (1,3) double = [-8; 8; 27]; % Initial conditions for the Lorenz system
        options.sigma (1,1) double = 10; % Lorenz's sigma parameter
        options.beta (1,1) double = 8/3; % Lorenz's beta parameter
        options.rho (1,1) double = 28; % Lorenz's rho parameter
    end

    lorenz = @(t,x) [
                options.sigma*(x(2)-x(1));
                x(1)*(options.rho-x(3))-x(2);
                x(1)*x(2)-options.beta*x(3);
            ];

    n = 3; % number of state variables

    % Integrate
    tspan=dt:dt:final_time;
    odeopts = odeset('RelTol',1e-12,'AbsTol',1e-12*ones(1,n));
    [t,xdat]=ode45(lorenz,tspan,options.x0,odeopts);
end