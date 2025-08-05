function [t,xdat] = rossler_generate(dt, final_time, options)
%ROSSLER_GENERATE
    arguments
        dt (1,1) double
        final_time (1,1) double
        options.x0 (3,1) double = [1; 1; 1];
        options.a (1,1) double = 0.1;
        options.b (1,1) double = 0.1;
        options.c (1,1) double = 14;
    end

    n = 3;
    rossler = @(t,x,a,b,c) [
                -x(2) - x(3);
                x(1) + a*x(2);
                b + x(3)*(x(1)-c);
            ];
    
    % Integrate
    tspan = dt:dt:final_time;
    [t,xdat] = ode45(@(t,x) rossler(t,x,options.a,options.b,options.c), ...
        tspan, options.x0, odeset('RelTol',1e-12,'AbsTol',1e-12*ones(1,n)));
end

