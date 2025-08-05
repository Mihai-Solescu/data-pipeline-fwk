function [t,xdat] = duffing_generate(dt, final_time, options)
    arguments
        dt (1,1) double
        final_time (1,1) double
        options.x0 (2,1) double = [0; .01];
        options.d (1,1) double = 0.02;
        options.a (1,1) double = 1;
        options.b (1,1) double = 5; 
        options.w (1,1) double = .5;
        options.g (1,1) double = 8; 
    end

    n = 2;
    duffing = @(t,x,d,a,b,w,g) [
                  x(2);
                  -d*x(2) - a*x(1) - b*x(1)^3 + g*cos(w*t);
              ];
    % Integrate
    tspan = dt:dt:final_time;
    [t,xdat] = ode45(@(t,x) duffing(t,x,options.d,options.a,options.b,options.w,options.g), ...
        tspan, options.x0, odeset('RelTol',1e-12,'AbsTol',1e-12*ones(1,n)));
end


