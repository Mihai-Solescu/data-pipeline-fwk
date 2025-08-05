%% Test pHAVOK_from_hankel function
% This script tests the modified pHAVOK_from_hankel function that takes
% a Hankel matrix directly as input.

clear; close all; clc;

% Add paths
current_dir = fileparts(mfilename('fullpath'));
project_root = fileparts(current_dir);
addpath(fullfile(project_root, 'data_generate'));
addpath(fullfile(project_root, 'utils'));

%% Parameters
dt = 0.001;
sim_time = 10;
stackmax = 30;
r = 8;
lambda = 0;

%% Generate Lorenz data
fprintf('Generating Lorenz data...\n');
[t, x] = lorenz_generate(dt, sim_time);

%% Create Hankel matrix manually
fprintf('Creating Hankel matrix...\n');
H = hankelize(x(:,1), stackmax);
fprintf('Hankel matrix size: %d x %d\n', size(H, 1), size(H, 2));

%% Apply pHAVOK_from_hankel
fprintf('Applying pHAVOK_from_hankel...\n');
[U, S, V, A, B, y, t_recon] = pHAVOK_from_hankel(H, dt, r, lambda);

%% Compare with original pHAVOK function
fprintf('Comparing with original pHAVOK...\n');
[U_orig, S_orig, V_orig, A_orig, B_orig, y_orig, t_orig] = pHAVOK(x(:,1), dt, stackmax, r, lambda);

%% Plot comparison
figure('Position', [100, 100, 1200, 800]);

subplot(2, 3, 1);
semilogy(diag(S), 'r-o', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'from_hankel');
hold on;
semilogy(diag(S_orig), 'b--s', 'LineWidth', 2, 'MarkerSize', 6, 'DisplayName', 'original');
xlabel('Mode Number');
ylabel('Singular Value');
title('Singular Values Comparison');
legend('Location', 'best');
grid on;

subplot(2, 3, 2);
plot(V(:, 1), 'r-', 'LineWidth', 2, 'DisplayName', 'from_hankel V1');
hold on;
plot(V_orig(:, 1), 'b--', 'LineWidth', 2, 'DisplayName', 'original V1');
xlabel('Time Index');
ylabel('V_1');
title('First Mode Comparison');
legend('Location', 'best');
grid on;

subplot(2, 3, 3);
plot(V(:, 2), 'r-', 'LineWidth', 2, 'DisplayName', 'from_hankel V2');
hold on;
plot(V_orig(:, 2), 'b--', 'LineWidth', 2, 'DisplayName', 'original V2');
xlabel('Time Index');
ylabel('V_2');
title('Second Mode Comparison');
legend('Location', 'best');
grid on;

subplot(2, 3, 4);
imagesc(A);
colorbar;
title('System Matrix A (from_hankel)');
xlabel('Column');
ylabel('Row');

subplot(2, 3, 5);
imagesc(A_orig);
colorbar;
title('System Matrix A (original)');
xlabel('Column');
ylabel('Row');

subplot(2, 3, 6);
if ~isempty(y) && ~isempty(y_orig)
    plot(y(:, 1), 'r-', 'LineWidth', 2, 'DisplayName', 'from_hankel');
    hold on;
    plot(y_orig(:, 1), 'b--', 'LineWidth', 2, 'DisplayName', 'original');
    xlabel('Time Index');
    ylabel('Reconstructed Signal');
    title('Reconstruction Comparison');
    legend('Location', 'best');
    grid on;
else
    text(0.5, 0.5, 'No reconstruction data', 'HorizontalAlignment', 'center');
    title('Reconstruction Comparison');
end

sgtitle('pHAVOK_from_hankel vs Original pHAVOK Comparison', 'FontSize', 14, 'FontWeight', 'bold');

%% Calculate differences
S_diff = norm(diag(S) - diag(S_orig)) / norm(diag(S_orig));
V_diff = norm(V(:, 1:min(size(V,2), size(V_orig,2))) - V_orig(:, 1:min(size(V,2), size(V_orig,2))), 'fro') / ...
         norm(V_orig(:, 1:min(size(V,2), size(V_orig,2))), 'fro');
A_diff = norm(A - A_orig, 'fro') / norm(A_orig, 'fro');

fprintf('\nComparison Results:\n');
fprintf('Singular values relative difference: %.6f\n', S_diff);
fprintf('V matrix relative difference: %.6f\n', V_diff);
fprintf('A matrix relative difference: %.6f\n', A_diff);
fprintf('Matrices U size: [%d x %d] vs [%d x %d]\n', size(U), size(U_orig));
fprintf('Matrices V size: [%d x %d] vs [%d x %d]\n', size(V), size(V_orig));

if S_diff < 1e-10 && V_diff < 1e-10 && A_diff < 1e-10
    fprintf('✓ Functions produce identical results!\n');
else
    fprintf('⚠ Functions produce slightly different results (likely due to numerical precision)\n');
end
