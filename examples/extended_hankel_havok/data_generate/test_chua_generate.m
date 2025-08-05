%% Test Chua's Circuit Generation
% This script generates and visualizes time series data from Chua's circuit,
% famous for its "double scroll" attractor.

% Clear workspace, close figures, and clear command window
clear; close all; clc;

%% --- 1. Generate Chua's Circuit Data ---

% Set simulation parameters
dt = 0.01;        % Time step
t_end = 500;       % Total simulation time
x0 = [0.7; 0; 0]; % Initial condition

fprintf('Generating Chua''s circuit data...\n');
[t, xdat] = chua_generate(dt, t_end, x0);
fprintf('Data generated with size: %d x %d\n\n', size(xdat, 1), size(xdat, 2));

%% --- 2. Plot the Chua Attractor (Double Scroll) ---

figure;
plot3(xdat(:,1), xdat(:,2), xdat(:,3), 'LineWidth', 1, 'Color', [0.6350, 0.0780, 0.1840]);
hold on;
p_start = plot3(xdat(1,1), xdat(1,2), xdat(1,3), 'go', 'MarkerSize', 10, 'MarkerFaceColor', 'g');
p_end = plot3(xdat(end,1), xdat(end,2), xdat(end,3), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
xlabel('x');
ylabel('y');
zlabel('z');
title('Chua Attractor: The Double Scroll');
legend([p_start, p_end], {'Start', 'End'}, 'Location', 'best');
axis tight;
grid on;
view(20, 15); % Optimal view for the double scroll
set(gca, 'FontSize', 14);
set(gcf, 'Position', [100 100 800 600]);

%% --- 3. Create an Animation of the Trajectory ---

figure;
% Plot the full trajectory in a lighter color
plot3(xdat(:,1), xdat(:,2), xdat(:,3), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
hold on;
% Initial particle position
p_anim = plot3(xdat(1,1), xdat(1,2), xdat(1,3), 'mo', 'MarkerSize', 8, 'MarkerFaceColor', 'm');
title('Chua''s Circuit Particle Animation');
xlabel('x');
ylabel('y');
zlabel('z');
axis tight;
grid on;
view(20, 15);
set(gca, 'FontSize', 14);
set(gcf, 'Position', [950 100 800 600]);

% Animation loop
step = 100; % Skip frames for a faster animation
for i = 1:step:length(t)
    set(p_anim, 'XData', xdat(i,1), 'YData', xdat(i,2), 'ZData', xdat(i,3));
    drawnow;
    pause(0.01);
end
