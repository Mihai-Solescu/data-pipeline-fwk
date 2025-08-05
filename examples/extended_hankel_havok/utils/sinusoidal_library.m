function [Theta, column_names] = sinusoidal_library(xdat, options)
    % SINUSOIDAL_LIBRARY Constructs a library of sine and cosine functions for system identification.
    %
    % This function generates a comprehensive library of sinusoidal basis functions
    % (sine and cosine terms) from input data for use in sparse regression, SINDy,
    % HAVOK, and other data-driven modeling approaches. The library includes harmonics
    % up to a specified maximum order, providing a rich set of trigonometric features
    % for capturing oscillatory and periodic behavior in dynamical systems.
    %
    % INPUTS:
    %   xdat          - Input data matrix (N x d) where:
    %                   N is the number of data points (observations)
    %                   d is the number of spatial dimensions/variables
    %   options.nVars         - Number of variables to use from xdat (positive integer)
    %                           (default: d, must satisfy 1 <= nVars <= d)
    %                           Only the first nVars columns of xdat will be used
    %   options.max_harmonics - Maximum harmonic number to include (positive integer)
    %                           (default: 10, matching poolData behavior from SINDy literature)
    %                           Generates terms sin(k*x_i) and cos(k*x_i) for k = 1, 2, ..., max_harmonics
    %
    % OUTPUTS:
    %   Theta        - Sinusoidal library matrix (N x num_terms) where:
    %                  num_terms = 2 * nVars * max_harmonics
    %                  Each row contains the sinusoidal features for one data point
    %   column_names - Cell array of strings with descriptive names for each column in Theta
    %                  Format: 'sin(x_i)', 'cos(x_i)', 'sin(k*x_i)', 'cos(k*x_i)'
    %
    % MATHEMATICAL FORMULATION:
    %   For each harmonic k = 1, 2, ..., max_harmonics and each variable i = 1, 2, ..., nVars:
    %   - Sine terms: sin(k * x_i(t)) for all time points t
    %   - Cosine terms: cos(k * x_i(t)) for all time points t
    %   
    %   Column ordering (for nVars variables and max_harmonics harmonics):
    %   [sin(x_1), sin(x_2), ..., sin(x_nVars), cos(x_1), cos(x_2), ..., cos(x_nVars),
    %    sin(2*x_1), sin(2*x_2), ..., sin(2*x_nVars), cos(2*x_1), cos(2*x_2), ..., cos(2*x_nVars),
    %    ..., sin(max_harmonics*x_1), ..., cos(max_harmonics*x_nVars)]
    %
    % EXAMPLE 1: Basic 2D sinusoidal library with 1 harmonic
    %   xdat = [0 pi/2; pi/4 3*pi/4; pi/2 pi]; % 3x2 matrix
    %   [Theta, column_names] = sinusoidal_library(xdat, 'nVars', 2, 'max_harmonics', 1);
    %   % Result: 
    %   % column_names = {'sin(x_1)', 'sin(x_2)', 'cos(x_1)', 'cos(x_2)'}
    %   % Theta = [sin(0)     sin(π/2)   cos(0)     cos(π/2)  ]   [0      1      1      0    ]
    %   %         [sin(π/4)   sin(3π/4)  cos(π/4)   cos(3π/4) ] = [√2/2   √2/2   √2/2  -√2/2 ]
    %   %         [sin(π/2)   sin(π)     cos(π/2)   cos(π)    ]   [1      0      0     -1    ]
    %   % Size: 3 x 4, num_terms = 2 * 2 * 1 = 4
    %
    % EXAMPLE 2: 2D sinusoidal library with 2 harmonics
    %   xdat = [1 2; 3 4]; % 2x2 matrix
    %   [Theta, column_names] = sinusoidal_library(xdat, 'nVars', 2, 'max_harmonics', 2);
    %   % Result:
    %   % column_names = {'sin(x_1)', 'sin(x_2)', 'cos(x_1)', 'cos(x_2)', 
    %   %                 'sin(2*x_1)', 'sin(2*x_2)', 'cos(2*x_1)', 'cos(2*x_2)'}
    %   % Theta = [sin(1)   sin(2)   cos(1)   cos(2)   sin(2)    sin(4)    cos(2)    cos(4)   ]
    %   %         [sin(3)   sin(4)   cos(3)   cos(4)   sin(6)    sin(8)    cos(6)    cos(8)   ]
    %   % Size: 2 x 8, num_terms = 2 * 2 * 2 = 8
    %
    % EXAMPLE 3: Subset of variables (3D data, use first 2 variables)
    %   xdat = [1 2 3; 4 5 6; 7 8 9]; % 3x3 matrix
    %   [Theta, column_names] = sinusoidal_library(xdat, 'nVars', 2, 'max_harmonics', 1);
    %   % Only uses columns 1 and 2 of xdat (ignores column 3)
    %   % Result:
    %   % column_names = {'sin(x_1)', 'sin(x_2)', 'cos(x_1)', 'cos(x_2)'}
    %   % Theta = [sin(1)   sin(2)   cos(1)   cos(2)]
    %   %         [sin(4)   sin(5)   cos(4)   cos(5)]
    %   %         [sin(7)   sin(8)   cos(7)   cos(8)]
    %   % Size: 3 x 4, num_terms = 2 * 2 * 1 = 4
    %
    % EXAMPLE 4: Single variable with multiple harmonics
    %   xdat = [0; pi/6; pi/4; pi/3; pi/2]; % 5x1 matrix
    %   [Theta, column_names] = sinusoidal_library(xdat, 'nVars', 1, 'max_harmonics', 3);
    %   % Result:
    %   % column_names = {'sin(x_1)', 'cos(x_1)', 'sin(2*x_1)', 'cos(2*x_1)', 'sin(3*x_1)', 'cos(3*x_1)'}
    %   % Theta = [0      1      0        1        0        1      ]  % x = 0
    %   %         [1/2    √3/2   √3/2     1/2      1        0      ]  % x = π/6
    %   %         [√2/2   √2/2   1        0        √2/2    -√2/2   ]  % x = π/4
    %   %         [√3/2   1/2    √3/2    -1/2     0       -1      ]  % x = π/3
    %   %         [1      0     -1        1        0        1      ]  % x = π/2
    %   % Size: 5 x 6, num_terms = 2 * 1 * 3 = 6
    %
    % NOTES:
    %   - Input data is assumed to be in appropriate units for trigonometric functions
    %   - For time series data, consider normalizing or scaling inputs for numerical stability
    %   - The function automatically limits nVars to the actual number of columns in xdat
    %   - Column ordering follows the harmonic-wise pattern for systematic feature selection
    %   - Compatible with sparse regression algorithms that can handle dense sinusoidal features
    %   - Pairs naturally with polyorder_library for comprehensive feature libraries
    %
    % SEE ALSO:
    %   polyorder_library, extended_hankelize, horizontal_hankel, vertical_hankel

    arguments
        xdat double
        options.nVars double = size(xdat, 2)
        options.max_harmonics double = 10
    end

    [~, d] = size(xdat);
    
    % Ensure nVars doesn't exceed actual data dimensions
    nVars = min(options.nVars, d);
    
    % Initialize empty library
    Theta = [];
    column_names = {};
    
    % Generate sin and cos terms for each harmonic and each variable
    for k = 1:options.max_harmonics
        for i = 1:nVars
            % Add sin term
            Theta = [Theta, sin(k * xdat(:, i))];
            if k == 1
                column_names{end+1} = ['sin(x_' num2str(i) ')'];
            else
                column_names{end+1} = ['sin(' num2str(k) '*x_' num2str(i) ')'];
            end
        end
        for i = 1:nVars
            % Add cos term
            Theta = [Theta, cos(k * xdat(:, i))];
            if k == 1
                column_names{end+1} = ['cos(x_' num2str(i) ')'];
            else
                column_names{end+1} = ['cos(' num2str(k) '*x_' num2str(i) ')'];
            end
        end
    end
end
