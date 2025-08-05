% This script tests the chen_generate function and visualizes the result.

% Clear workspace, close figures, and clear command window
clear; close all; clc;

% Add the data_generate path
addpath(pwd); % Assuming the script is run from data_generate

% --- 1. Generate Chen Attractor Data ---
fprintf('Generating data from the Chen attractor...\n');

% Use default parameters
[t, x] = chen_generate();

fprintf('Data generation complete.\n\n');

% --- 2. Visualize the Attractor ---
fprintf('Plotting the Chen attractor...\n');

figure;
plot3(x(:,1), x(:,2), x(:,3));
xlabel('x');
ylabel('y');
zlabel('z');
title('Chen Attractor');
grid on;

fprintf('Test script finished.\n');
