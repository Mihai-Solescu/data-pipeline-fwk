function [t,xdat] = mackey_glass_generate(dt,final_time)

    arguments
        dt (1,1) double
        final_time (1,1) double
    end

    mackey_glass = @(t,y,ytau,gamma,beta,n) beta*(ytau/(1+ytau^n)) - gamma*y;
    gamma = 1;
    beta = 2;
    tau = 2;
    n = 9.65;

    % Integrate
    tspan = 0:dt:final_time;
    
    options = ddeset('MaxStep',dt);
    sol=dde23(@(t,y,ytau) mackey_glass(t,y,ytau,gamma,beta,n),2,.5,tspan,options);
    t = sol.x;
    xdat = (sol.y)';
    xdat = interp1(t,xdat,tspan,'spline');
    xdat = xdat';
end