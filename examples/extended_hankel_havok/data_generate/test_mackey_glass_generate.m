%% Generate the system time series
dt = 0.001;
[t, xdat] = mackey_glass_generate(dt, 100);
size(xdat); % 100001 x 1

%% Plot the system
figure;
plot(xdat(:,1));
xlabel('x_1')
title('Mackey-Glass Timeseries');
axis tight
set(gca, 'FontSize', 14);
set(gcf, 'Position', [100 100 800 600]);
set(gcf, 'PaperPositionMode', 'auto');