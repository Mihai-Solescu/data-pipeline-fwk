function print_sum(coeffs, names)
    % Helper function to print equations nicely
    % coeffs: Coefficients of the terms (e.g., [a, b, c])
    % names: Names of the terms (e.g., 'x', 'y', 'z', etc.)
    % Example usage: print_eq([1, -2, 3], {'x', 'y', 'z'})
    % This will print: '1*x - 2*y + 3*z'

    eq = '';
    for i = 1:length(coeffs)
        if coeffs(i) ~= 0
            if ~isempty(eq) && coeffs(i) > 0
                eq = [eq, ' + '];
            elseif ~isempty(eq)
                eq = [eq, ' - '];
            elseif coeffs(i) < 0
                eq = [eq, '-'];
            end
            
            if abs(coeffs(i)) ~= 1 || strcmp(names{i}, '1')
                eq = [eq, num2str(abs(coeffs(i)), '%.3f')];
            end
            
            if ~strcmp(names{i}, '1')
                if abs(coeffs(i)) ~= 1
                    eq = [eq, '*'];
                end
                eq = [eq, names{i}];
            end
        end
    end
    if isempty(eq)
        eq = '0';
    end
    fprintf('%s\n', eq);
end