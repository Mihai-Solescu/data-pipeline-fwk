function out = compute_numerical_derivative(in, p)

    out.dVdt = numerical_derivative(in.V, p.dt); % Function exists, don't redefine it

end