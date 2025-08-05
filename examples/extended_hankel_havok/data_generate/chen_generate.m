function [t, x] = chen_generate(x0, tspan, params)
% CHEN_GENERATE - Generates data from the Chen attractor.
%
% Syntax: [t, x] = chen_generate(x0, tspan, params)
%
% Inputs:
%   x0 (1x3 double): Initial condition [x(0), y(0), z(0)].
%       Default: [-10, 0, 37]
%   tspan (1x2 double): Time interval [t_start, t_end].
%       Default: [0, 100] with a time step of 0.01.
%   params (struct): Parameters of the Chen system.
%       .a (double): Default: 35
%       .b (double): Default: 3
%       .c (double): Default: 28
%
% Outputs:
%   t (Nx1 double): Time vector.
%   x (Nx3 double): State variables [x(t), y(t), z(t)].

% Set default parameters if not provided.
if nargin < 3
    params.a = 35;
    params.b = 3;
    params.c = 28;
end
if nargin < 2
    dt = 0.01;
    tspan = 0:dt:100;
end
if nargin < 1
    x0 = [-10, 0, 37];
end

% Define the Chen system ODEs.
f = @(t, x) [params.a * (x(2) - x(1)); ...
             (params.c - params.a) * x(1) - x(1) * x(3) + params.c * x(2); ...
             x(1) * x(2) - params.b * x(3)];

% Solve the ODEs.
[t, x] = ode45(f, tspan, x0);

end
