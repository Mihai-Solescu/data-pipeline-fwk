%% Test script for pHAVOK
% This script tests the pHAVOK function with various options.

% Add paths to the required functions, prioritizing utils directory
addpath(genpath('../utils'));
addpath(genpath('../data_generate'));
addpath(genpath('../'));

%% Generate Lorenz data
dt = 0.001;
final_time = 100;
[~, x] = lorenz_generate(dt, final_time);

%% Test 1: pHAVOK with polynomial terms only
disp('Running Test 1: pHAVOK with polynomial terms...');
r = 15;
lambda = 0;
[~,~,~,A,B] = pHAVOK(x, dt, 100, r, lambda, 'polyorder', 1, 'use_sinusoid', false);

% Assertions
assert(size(A, 1) == r-1, 'Test 1 failed: A matrix has incorrect row dimension.');
assert(size(A, 2) == r-1, 'Test 1 failed: A matrix has incorrect column dimension.');
assert(size(B, 1) == r-1, 'Test 1 failed: B matrix has incorrect row dimension.');
assert(size(B, 2) == 1, 'Test 1 failed: B matrix should have one column.');
disp('Test 1 passed.');

%% Test 2: pHAVOK with polynomial and sinusoidal terms
disp('Running Test 2: pHAVOK with polynomial and sinusoidal terms...');
r = 10;
lambda = 0;
[~,~,~,A,B] = pHAVOK(x, dt, 100, r, lambda, 'polyorder', 2, 'use_sinusoid', true);

% Assertions
assert(size(A, 1) == r-1, 'Test 2 failed: A matrix has incorrect row dimension.');
assert(size(A, 2) == r-1, 'Test 2 failed: A matrix has incorrect column dimension.');
assert(size(B, 1) == r-1, 'Test 2 failed: B matrix has incorrect row dimension.');
assert(size(B, 2) == 1, 'Test 2 failed: B matrix should have one column.');
disp('Test 2 passed.');

%% Test 3: Test with different r
disp('Running Test 3: pHAVOK with different r...');
r = 20;
lambda = 0;
[~,~,~,A,B] = pHAVOK(x, dt, 100, r, lambda, 'polyorder', 1, 'use_sinusoid', false);

% Assertions
assert(size(A, 1) == r-1, 'Test 3 failed: A matrix has incorrect row dimension.');
assert(size(A, 2) == r-1, 'Test 3 failed: A matrix has incorrect column dimension.');
assert(size(B, 1) == r-1, 'Test 3 failed: B matrix has incorrect row dimension.');
assert(size(B, 2) == 1, 'Test 3 failed: B matrix should have one column.');
disp('Test 3 passed.');

%% Test 4: Reconstruction of Lorenz System from HAVOK model
disp('Running Test 4: Reconstruction of Lorenz System...');
r = 15;
lambda = 0;
stackmax = 100;
[U,S,V,A,B] = pHAVOK(x, dt, stackmax, r, lambda, 'polyorder', 1, 'use_sinusoid', false);

% Test the reconstruction by comparing original V with reconstructed V
v_original = V(3:end-3, 1:r-1);
v_r = V(3:end-3, r);

% Simulate the linear system using the identified A and B matrices
sys = ss(A, B, eye(r-1), 0*B);
[v_recon, ~] = lsim(sys, v_r, (0:length(v_r)-1)*dt, v_original(1,:));

% Compare reconstruction in the V space (delay coordinates)
v_error = mean(vecnorm(v_original - v_recon, 2, 2));
fprintf('Reconstruction error in delay coordinates: %.4f\n', v_error);

% Project both original and reconstructed V back to original coordinates for comparison
% Since HAVOK uses only the first variable for Hankel matrix, we reconstruct only that variable
x_original_proj = (U(:, 1:r-1) * v_original')';  % Full projection from delay embedding
x_recon_proj = (U(:, 1:r-1) * v_recon')';

% Calculate reconstruction error in original space (first variable only)
x_error = mean(vecnorm(x_original_proj - x_recon_proj, 2, 2));
fprintf('Reconstruction error in original coordinates: %.4f\n', x_error);

% Assertions - use more reasonable thresholds
assert(size(x_recon_proj, 2) == size(x_original_proj, 2), 'Test 4 failed: Reconstructed data has incorrect dimensions.');
assert(v_error < 5, 'Test 4 failed: Reconstruction error in delay coordinates is too high.');
assert(x_error < 10, 'Test 4 failed: Reconstruction error in original coordinates is too high.');
disp('Test 4 passed.');

%% Test 5: Singular value decay validation
disp('Running Test 5: Singular value decay validation...');
r = 15;
lambda = 0;
stackmax = 100;
[~,S,~,~,~] = pHAVOK(x, dt, stackmax, r, lambda, 'polyorder', 1, 'use_sinusoid', false);

% Check singular value decay characteristic of chaotic systems
singular_values = diag(S);
energy_capture = cumsum(singular_values.^2) / sum(singular_values.^2);

% Assert that first r modes capture significant energy (>99%)
assert(energy_capture(r) > 0.99, 'Test 5 failed: First r modes should capture >99% of energy.');

% Check that singular values decay (characteristic of low-dimensional attractors)
decay_ratio = singular_values(end) / singular_values(1);
assert(decay_ratio < 1e-10, 'Test 5 failed: Singular values should show significant decay.');

fprintf('Energy captured by first %d modes: %.4f%%\n', r, energy_capture(r)*100);
fprintf('Singular value decay ratio: %.2e\n', decay_ratio);
disp('Test 5 passed.');

%% Test 6: Model prediction capability
disp('Running Test 6: Model prediction capability...');
r = 15;
lambda = 0;
stackmax = 50;
[~,~,V,A,B] = pHAVOK(x, dt, stackmax, r, lambda, 'polyorder', 1, 'use_sinusoid', false);

% Use only first half of data for training, predict second half
split_idx = floor(size(V,1) / 2);
v_train = V(3:split_idx, 1:r-1);
v_r_train = V(3:split_idx, r);

% Create state-space model and predict
sys = ss(A, B, eye(r-1), 0*B);
v_r_test = V(split_idx+1:end-3, r);
[v_pred, ~] = lsim(sys, v_r_test, (0:length(v_r_test)-1)*dt, v_train(end,:));

% Compare prediction with actual
v_actual = V(split_idx+1:end-3, 1:r-1);
pred_error = mean(vecnorm(v_actual - v_pred, 2, 2));

fprintf('Prediction error over %d time steps: %.4f\n', length(v_r_test), pred_error);
assert(pred_error < 1, 'Test 6 failed: Prediction error is too high.');
disp('Test 6 passed.');

disp('All tests passed successfully!');
