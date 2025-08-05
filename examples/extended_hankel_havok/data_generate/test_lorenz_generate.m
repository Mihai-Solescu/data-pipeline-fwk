%% Generate the Lorenz system time series
dt = 0.001;
[t, xdat] = lorenz_generate(dt, 200);
size(xdat); % 200000 x 3

%% Plot the Lorenz system
figure;
plot3(xdat(:,1), xdat(:,2), xdat(:,3), 'LineWidth', 1.5);
hold on;
p2 = plot3(xdat(1,1), xdat(1,2), xdat(1,3), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
xlabel('x_1'), ylabel('x_2'), zlabel('x_3')
title('Lorenz System Trajectory');
axis tight
set(gca, 'FontSize', 14);
view(34, 22);
set(gcf, 'Position', [100 100 800 600]);
set(gcf, 'PaperPositionMode', 'auto');

%% Create animation of a particle moving on the Lorenz system
figure;
plot3(xdat(:,1), xdat(:,2), xdat(:,3), 'Color', [0.7 0.7 0.7], 'LineWidth', 0.5);
hold on;
p1 = plot3(xdat(1,1), xdat(1,2), xdat(1,3), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
title('Lorenz System Particle Animation');
xlabel('x_1'), ylabel('x_2'), zlabel('x_3');
axis tight;
grid on;
view(34, 22);
set(gca, 'FontSize', 14);
set(gcf, 'Position', [100+800 100 800 600]);

%% Animation for both plots

step = 50; % Skip frames for faster animation
frames = floor(length(t)/step);

% Create animation
for i = 1:step:length(t)
    % Update particle position
    set(p1, 'XData', xdat(i,1), 'YData', xdat(i,2), 'ZData', xdat(i,3));
    set(p2, 'XData', xdat(i,1), 'YData', xdat(i,2), 'ZData', xdat(i,3));

    % Optional: add a trail
    if i > 100*step
        trail_length = 100;
        idx = max(1, i-step*trail_length):step:i;
        trail = plot3(xdat(idx,1), xdat(idx,2), xdat(idx,3), 'r-', 'LineWidth', 2);
    end
    
    drawnow;
    pause(0.01);
end