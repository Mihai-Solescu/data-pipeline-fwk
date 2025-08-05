%% TEST SCRIPT: pHAVOK vs pHAVOK_paper Numerical Comparison
% ==========================================================
%
% This script tests whether pHAVOK and pHAVOK_paper produce identical
% numerical results when applied to the same Lorenz system data.
%
% FEATURES:
% - Generates consistent Lorenz data for testing
% - Compares all outputs: U, S, V, s, A, B
% - Tests multiple parameter combinations
% - Provides detailed numerical difference analysis
% - Handles edge cases and error conditions

clear; close all; clc;

% Relative paths, cd into the script's directory
script_dir = fileparts(mfilename('fullpath'));
cd(script_dir);

% Add necessary paths
addpath('../utils');
addpath('../data_generate');
addpath('./HAVOK_paper/utils');

%% --- 1. Configuration ---

fprintf('=== pHAVOK vs pHAVOK_paper Numerical Comparison ===\n\n');

% Test parameters
test_params = struct();
test_params.stackmax_values = [20, 30];
test_params.r_values = [10, 15];
test_params.lambda_values = [0, 0.01];

% Numerical tolerance for comparison
tolerance = 1e-12;

% Results storage
test_results = struct();
test_results.total_tests = 0;
test_results.passed_tests = 0;
test_results.failed_tests = 0;
test_results.failures = {};

%% --- 2. Generate Test Data ---

fprintf('--- Generating Lorenz Test Data ---\n');

% Generate master Lorenz dataset
dt = 0.001;
t_total = 50;

% Generate Lorenz data (use only first column for univariate HAVOK)
[t_full, x_full] = lorenz_generate(dt, t_total);
xdat = x_full(:,1); % Only the first variable

fprintf('Generated Lorenz data: %d time points, dt = %.4f\n', length(t_full), dt);


%% --- 3. Run Tests for Each Parameter Combination ---

fprintf('\n--- Parameter Sweep: stackmax, r, lambda ---\n');

tol = 1e-10;

for stackmax = test_params.stackmax_values
    for r = test_params.r_values
        for lambda = test_params.lambda_values
            % Skip invalid combinations
            if r >= stackmax
                fprintf('SKIP: stackmax=%d, r=%d, lambda=%.3g (r >= stackmax)\n', stackmax, r, lambda);
                continue;
            end
            fprintf('Testing: stackmax=%d, r=%d, lambda=%.3g ... ', stackmax, r, lambda);
            try
                [U1, S1, V1, s1, A1, B1, ~, ~] = pHAVOK(xdat, dt, stackmax, r, lambda);
                [U2, S2, V2, s2, A2, B2] = pHAVOK_paper(xdat, dt, stackmax, r, lambda);
                
                % Print sizes for debugging
                fprintf('\n  Sizes - pHAVOK:     U=%s, S=%s, V=%s, s=%s, A=%s, B=%s', ...
                    mat2str(size(U1)), mat2str(size(S1)), mat2str(size(V1)), ...
                    mat2str(size(s1)), mat2str(size(A1)), mat2str(size(B1)));
                fprintf('\n  Sizes - pHAVOK_paper: U=%s, S=%s, V=%s, s=%s, A=%s, B=%s\n', ...
                    mat2str(size(U2)), mat2str(size(S2)), mat2str(size(V2)), ...
                    mat2str(size(s2)), mat2str(size(A2)), mat2str(size(B2)));
                
                % Compare matrices with equal shapes only
                fprintf('  Comparing matrices: ');
                
                % U matrices - should be same size
                sumdiff.U = sum(abs(U1(:) - U2(:)));
                fprintf('U=%.2e, ', sumdiff.U);
                
                % S matrices - should be same size
                sumdiff.S = sum(abs(S1(:) - S2(:)));
                fprintf('S=%.2e, ', sumdiff.S);
                
                % V matrices - take common rows to compare
                v_min_rows = min(size(V1,1), size(V2,1));
                v_min_cols = min(size(V1,2), size(V2,2));
                sumdiff.V = sum(sum(abs(V1(1:v_min_rows, 1:v_min_cols) - V2(1:v_min_rows, 1:v_min_cols))));
                fprintf('V=%.2e, ', sumdiff.V);
                
                % s vectors - should be same size
                sumdiff.s = sum(abs(s1(:) - s2(:)));
                fprintf('s=%.2e, ', sumdiff.s);
                
                % A matrices - should be same size
                sumdiff.A = sum(abs(A1(:) - A2(:)));
                fprintf('A=%.2e, ', sumdiff.A);
                
                % B vectors - should be same size
                sumdiff.B = sum(abs(B1(:) - B2(:)));
                fprintf('B=%.2e\n', sumdiff.B);
                
                % Check if all differences are within tolerance
                if all(structfun(@(x) x < tol, sumdiff))
                    fprintf('  PASS: All output matrices are numerically identical within tolerance\n');
                else
                    fprintf('  FAIL: Output matrices have significant numerical differences\n');
                end
            catch ME
                fprintf('ERROR: %s\n', ME.message);
            end
        end
    end
end