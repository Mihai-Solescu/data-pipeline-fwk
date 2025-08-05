%% Generate the system time series
dt = 0.001;
[t, xdat] = duffing_generate(dt, 200);
size(xdat); % 200000 x 2

%% Plot the system
figure;
plot(xdat(:,1), xdat(:,2), 'LineWidth', 1.5);
hold on;
p1 = plot(xdat(1,1), xdat(1,2), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 0.25);
xlabel('x_1'), ylabel('x_2')
title('Duffing System Trajectory');
axis tight
set(gca, 'FontSize', 14);
set(gcf, 'Position', [100 100 800 600]);
set(gcf, 'PaperPositionMode', 'auto');

%% Create animation of a moving particle
figure;
plot(xdat(:,1), xdat(:,2), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
hold on;
p2 = plot(xdat(1,1), xdat(1,2), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 0.25);
title('Duffing System Particle Animation');
xlabel('x_1'), ylabel('x_2');
axis tight;
grid on;
set(gca, 'FontSize', 14);
set(gcf, 'Position', [100+800 100 800 600]);

%% Animation for both plots

step = 50; % Skip frames for faster animation
frames = floor(length(t)/step);

% Create animation
for i = 1:step:length(t)
    % Update particle position
    set(p1, 'XData', xdat(i,1), 'YData', xdat(i,2));
    set(p2, 'XData', xdat(i,1), 'YData', xdat(i,2));
    
    % Optional: add a trail
    if i > 100*step
        trail_length = 100;
        idx = max(1, i-step*trail_length):step:i;
        trail = plot(xdat(idx,1), xdat(idx,2), 'r-', 'LineWidth', 2);
    end
    
    drawnow;
    pause(0.01);
end