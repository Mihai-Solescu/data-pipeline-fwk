primal = [0 0; 4 0; 6 0;  4 3; 0 6; 2 6; 4 6; 0 9];
dual = [0 0 0; 3 0 0; 0 0 1; -9/2 0 5/2; 0 5/2 0; 0 3/2 0; 3 5/2 0; 0 0 5/2];

figure('Position', [100, 100, 800, 800]);
scatter(primal(:,1), primal(:,2), 'filled', 'MarkerFaceColor', [0.2 0.6 0.8], 'MarkerEdgeColor', 'k', 'LineWidth', 1.5);

primal_augmented = [primal; ones(8,1)]