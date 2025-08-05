%% Generate the Lorenz system time series
dt = 0.001;
[t, xdat] = lorenz_generate(dt, 200);
size(xdat); % 200000 x 3


%% Plot 1: Nearest neighbors with fixed k = 100

p = xdat(2000,:);
X_nearest = k_nearest_neighbors(xdat, p, 100);

figure('Position', [100 100 800 600]);
plot3(xdat(:,1), xdat(:,2), xdat(:,3), 'b-', 'LineWidth', 1);
hold on;

plot3(xdat(X_nearest,1), xdat(X_nearest,2), xdat(X_nearest,3), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'black');
plot3(p(1,1), p(1,2), p(1,3), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'red');

grid on;
xlabel('x'); ylabel('y'); zlabel('z');
view(30, 20);
title('Nearest Neighbors with k = 100');
legend('Lorenz System', 'Nearest Neighbors');

%% Plot 2: Nearest neighbors with interactive k

% Create figure and plot system
fig = figure('Position', [100+800 100 800 600]);
plot3(xdat(:,1), xdat(:,2), xdat(:,3), 'b-', 'LineWidth', 1);
hold on;

% Set view and labels
grid on;
xlabel('x'); ylabel('y'); zlabel('z');
view(30, 20);

% Create slider with continuous updates
sld1 = uicontrol('Style', 'slider', ...
    'Position', [50 20 700 20], ...
    'Min', 0, 'Max', 200, ...
    'Value', 0, ...
    'SliderStep', [0.001 0.01]);

% Create point marker
point = plot3(xdat(1,1), xdat(1,2), xdat(1,3), 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r');
point_idx = 400; % Initialize point index

% Add listener for continuous updates
addlistener(sld1, 'ContinuousValueChange', @(src,evt) updatePoint(src, evt, xdat, dt, point, point_idx));

function updatePoint(src, ~, xdat, dt, point, p_idx)
    t = src.Value;
    idx = max(1, round(t/dt)); % Convert time to index using dt=0.001
    idx = min(idx, size(xdat,1)); % Ensure index doesn't exceed data size
    point.XData = xdat(idx,1);
    point.YData = xdat(idx,2);
    point.ZData = xdat(idx,3);
    p_idx = idx; % Update point index
    drawnow
end

sld2 = uicontrol('Style', 'slider', ...
    'Position', [50 50 700 20], ...
    'Min', 0, 'Max', 200, ...
    'Value', 0, ...
    'SliderStep', [0.001 0.01]);

% Add nearest neighbors plot
nearest_neighbors_plot = plot3(xdat(1,1), xdat(1,2), xdat(1,3), 'bo', 'MarkerSize', 10, 'MarkerFaceColor', 'black');

addlistener(sld2, 'ContinuousValueChange', @(src,evt) updateNearestNeighbors(src, evt, xdat, point_idx, nearest_neighbors_plot));

function updateNearestNeighbors(src, ~, xdat, point_idx, nearest_neighbors_plot)
    k = src.Value;

    k = max(1, round(k)); % Ensure k is at least 1
    k = min(k, size(xdat,1)); % Ensure k doesn't exceed data size
    p = xdat(point_idx, :); % Get the current point
    
    X_nearest = k_nearest_neighbors(xdat, p, k); % Find nearest neighbors
    nearest_neighbors_plot.XData = xdat(X_nearest,1);
    nearest_neighbors_plot.YData = xdat(X_nearest,2);
    nearest_neighbors_plot.ZData = xdat(X_nearest,3);
    
    drawnow
end