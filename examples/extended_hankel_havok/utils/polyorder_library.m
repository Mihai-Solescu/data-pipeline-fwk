function [Theta, column_names] = polyorder_library(xdat, polyorder, options)
    % POLYORDER_LIBRARY Constructs a polynomial library of candidate functions
    % for system identification using polynomial regression.
    %
    % This function generates a comprehensive polynomial library containing
    % monomial terms up to a specified maximum degree. The library can include
    % both pure powers (e.g., x^2, y^3) and cross terms (e.g., xy, x^2y) 
    % depending on the configuration options.
    %
    % INPUTS:
    %   xdat      - Data points (matrix of size N x d, where N is the number of data points and d is the number of dimensions)
    %   polyorder - Maximum polynomial order (positive integer)
    %               The total degree of any monomial term will not exceed this value
    %   options.use_cross_terms - (Optional) Flag to include cross-product terms
    %                           (default: true, logical)
    %                           If true: includes mixed terms like xy, x^2y, xyz
    %                           If false: includes only pure powers like x^2, y^3, z^4
    %
    % OUTPUTS:
    %   Theta        - Library matrix of candidate functions evaluated at data points
    %                  Size: (N x num_terms) where num_terms depends on polyorder,
    %                  dimensions d, and use_cross_terms setting
    %   column_names - Cell array of strings with descriptive names for each column in Theta
    %                  Format: 'x_i^k' for pure powers, 'x_i*x_j*...' for cross terms
    %
    % MATHEMATICAL FORMULATION:
    %   For a d-dimensional input x = [x_1, x_2, ..., x_d]:
    %   
    %   With use_cross_terms = true (default):
    %   - Generates all monomials x_1^{k_1} * x_2^{k_2} * ... * x_d^{k_d}
    %   - Subject to constraint: k_1 + k_2 + ... + k_d <= polyorder
    %   - Total terms: sum_{k=0}^{polyorder} C(d+k-1, k) = C(d+polyorder, polyorder)
    %   
    %   With use_cross_terms = false:
    %   - Generates only pure powers: x_i^k for i=1..d, k=0..polyorder  
    %   - Total terms: 1 + d*polyorder (constant + d variables * polyorder powers each)
    %
    % EXAMPLE 1: Full polynomial library with cross terms (default)
    %   xdat = [x y z];  % 3D data
    %   polyorder = 2;
    %   [Theta, column_names] = polyorder_library(xdat, 2);
    %   % Result: Theta = [1 x y z x^2 xy xz y^2 yz z^2];
    %   % column_names = {'1', 'x_1', 'x_2', 'x_3', 'x_1^2', 'x_1*x_2', 'x_1*x_3', 'x_2^2', 'x_2*x_3', 'x_3^2'};
    %   % Total: 10 terms for 3D quadratic polynomial
    %
    % EXAMPLE 2: Pure powers only (no cross terms)
    %   xdat = [x y z];  % 3D data  
    %   polyorder = 3;
    %   [Theta, column_names] = polyorder_library(xdat, 3, 'use_cross_terms', false);
    %   % Result: Theta = [1 x y z x^2 xy xz y^2 yz z^2 x^3 x^2y x^2z xy^2 xyz y^3 y^2z yz^2];
    %   % column_names = {'1', 'x_1', 'x_2', 'x_3', 'x_1^2', 'x_2^2', 'x_3^2', 'x_1^3', 'x_2^3', 'x_3^3'};
    %   % Total: 10 terms (1 constant + 3 variables * 3 powers each)
    %
    % EXAMPLE 3: Cross terms enabled for higher-order polynomial
    %   xdat = [x y];    % 2D data
    %   polyorder = 3;
    %   [Theta, column_names] = polyorder_library(xdat, 3, 'use_cross_terms', true);
    %   % Result: Theta = [1 x y x^2 xy y^2 x^3 x^2y xy^2 y^3];
    %   % column_names = {'1', 'x_1', 'x_2', 'x_1^2', 'x_1*x_2', 'x_2^2', 'x_1^3', 'x_1^2*x_2', 'x_1*x_2^2', 'x_2^3'};
    %   % Total: 10 terms for 2D cubic polynomial
    % EXAMPLE 4: Cross terms enabled for higher-order polynomial with mixed terms
    %   xdat = [x y z];    % 3D data
    %   polyorder = 3;
    %   [Theta, column_names] = polyorder_library(xdat, 3, 'use_cross_terms', true);
    %   % Result: Theta = [1 x y z x^2 xy xz y^2 yz z^2 x^3 x^2y x^2z xy^2 xyz xz^2 y^3 y^2z yz^2 z^3];
    %   % column_names = {'1', 'x_1', 'x_2', 'x_3', 'x_1^2', 'x_1*x_2', 'x_1*x_3', 'x_2^2', 'x_2*x_3', 'x_3^2', 'x_1^3', 'x_1^2*x_2', 'x_1^2*x_3', 'x_1*x_2^2', 'x_1*x_2*x_3', 'x_1*x_3^2', 'x_2^3', 'x_2^2*x_3', 'x_2*x_3^2', 'x_3^3'};
    %   % Total: 20 terms for 3D cubic polynomial with mixed terms
    
    arguments
        xdat (:,:) double {mustBeNonempty}
        polyorder (1,1) int32 {mustBeInteger, mustBePositive}
        options.use_cross_terms (1,1) logical = true
    end
    
    [N, d] = size(xdat);
    
    % Initialize the library with a column of ones (constant term)
    Theta = ones(N, 1);
    
    % Initialize column names with the constant term
    column_names = {'1'};
    
    if options.use_cross_terms
        % Generate full polynomial library with cross terms (original behavior)
        % Generate polynomial terms up to the specified order
        for order = 1:polyorder
            % Generate all combinations of indices for the current order (with repetition)
            indices = multichoosek(1:d, order);

            for i = 1:size(indices, 1)
                term = prod(xdat(:, indices(i, :)), 2); % Compute the product of selected variables
                Theta = [Theta, term]; % Append the new term to the library
                
                % Create column name for this term
                term_name = '';
                var_counts = histcounts(indices(i, :), 1:d+1);
                
                % Build term name based on the powers of each variable
                for j = 1:d
                    if var_counts(j) > 0
                        if ~isempty(term_name)
                            term_name = [term_name '*'];
                        end
                        if var_counts(j) == 1
                            term_name = [term_name 'x_' num2str(j)];
                        else
                            term_name = [term_name 'x_' num2str(j) '^' num2str(var_counts(j))];
                        end
                    end
                end
                
                column_names{end+1} = term_name;
            end
        end
    else
        % Generate only pure powers (no cross terms)
        % For each polynomial order from 1 to polyorder
        for order = 1:polyorder
            % For each variable dimension
            for var_idx = 1:d
                % Create pure power term: x_var_idx^order
                term = xdat(:, var_idx).^double(order);
                Theta = [Theta, term];
                
                % Create column name for pure power
                if order == 1
                    term_name = ['x_' num2str(var_idx)];
                else
                    term_name = ['x_' num2str(var_idx) '^' num2str(order)];
                end
                
                column_names{end+1} = term_name;
            end
        end
    end
end

% Local helper to generate combinations with repetition
function C = multichoosek(values, k)
    if k == 0
        C = zeros(1, 0);
    elseif k == 1
        C = values(:);
    else
        n = numel(values);
        % Generate indices for combinations with repetition
        idx = nchoosek(1:n + k - 1, k);
        C = zeros(size(idx));
        for i = 1:k
            C(:, i) = values(idx(:, i) - i + 1);
        end
    end
end