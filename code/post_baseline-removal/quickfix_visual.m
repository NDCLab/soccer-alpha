% batch_visual_soccer.m
% visualization script for soccer erp data
% author: marlene buch
% date: 2025-10-15

%% paths
diffWaves = "C:\Users\localadmin\Documents\08_SocCEr\soccer-alpha\derivatives\2025-10-16_erp-postprocessing-baselined\difference_waves";
grandAver = "C:\Users\localadmin\Documents\08_SocCEr\soccer-alpha\derivatives\2025-10-16_erp-postprocessing-baselined\grand_averages";

%% color definitions
schwarz = [0 0 0];
grau = [105 105 105];

% visible conditions
vis_cor = [52 91 235];
vis_err = [194 35 69];
vis_FE  = [144 30 201];
vis_NFE = [163 18 124];

% invisible conditions  
invis_NFG = [140 160 50];
invis_FE = [144 30 201];   % same as vis_FE


%% ========================================================================
%% VISIBLE-TARGET
%% ========================================================================

%% grand averages
visual_comperp({'grandAVG_111_social_vis_corr', 'grandAVG_211_nonsoc_vis_corr', ...
                'grandAVG_112_social_vis_FE', 'grandAVG_212_nonsoc_vis_FE', ...
                'grandAVG_113_social_vis_NFE', 'grandAVG_213_nonsoc_vis_NFE'}, ...
                char(grandAver));

% ERN
pimpfigure('ERP', [-150 400 -2.5 3], {'1' '1:' '3' '3:' '5' '5:'}, ...
           {'correct social (N = 29)', 'correct nonsocial (N = 29)', 'FE social (N = 25)', 'FE nonsocial (N = 26)', 'NFE social (N = 22)', 'NFE nonsocial (N = 23)'}, ...
           [0 100], [vis_cor; vis_cor; vis_FE; vis_FE; vis_NFE; vis_NFE]);
title('Ne/ERN - visible-target - grand averages');

% Pe
pimpfigure('ERP', [-100 600 -2 3.5], {'1' '1:' '3' '3:' '5' '5:'}, ...
           {'correct social (N = 29)', 'correct nonsocial (N = 29)', 'FE social (N = 25)', 'FE nonsocial (N = 26)', 'NFE social (N = 22)', 'NFE nonsocial (N = 23)'}, ...
           [200 500], [vis_cor; vis_cor; vis_FE; vis_FE; vis_NFE; vis_NFE]);
title('Pe - visible-target - grand averages');

%% difference waves
visual_comperp({'diffWave_soc_vis_FE', 'diffWave_nonsoc_vis_FE', ...
                'diffWave_soc_vis_NFE', 'diffWave_nonsoc_vis_NFE'}, ...
                char(diffWaves));

% ERN
pimpfigure('ERP', [-150 400 -2 2.5], {'1' '1:' '3' '3:'}, ...
           {'FE social (N = 25)', 'FE nonsocial (N = 26)', 'NFE social (N = 22)', 'NFE nonsocial (N = 23)'}, ...
           [0 100], [vis_FE; vis_FE; vis_NFE; vis_NFE]);
title('∆ERN - visible-target');

% Pe
pimpfigure('ERP', [-100 600 -1.5 3.5], {'1' '1:' '3' '3:'}, ...
           {'FE social (N = 25)', 'FE nonsocial (N = 26)', 'NFE social (N = 22)', 'NFE nonsocial (N = 23)'}, ...
           [200 500], [vis_FE; vis_FE; vis_NFE; vis_NFE]);
title('∆Pe - visible-target');


%% additional tests - visible-target - collapsed errors (FE + NFE combined)
%% grand averages
visual_comperp({'grandAVG_111_social_vis_corr', 'grandAVG_211_nonsoc_vis_corr', ...
                'grandAVG_110_social_vis_error', 'grandAVG_210_nonsoc_vis_error'}, ...
                char(grandAver));

% ERN
pimpfigure('ERP', [-1000 400 -2.5 3], {'1' '1:' '3' '3:'}, ...
           {'correct social (N = 29)', 'correct nonsocial (N = 29)', 'error social (N = 26)', 'error nonsocial (N = 26)'}, ...
           [0 100], [vis_cor; vis_cor; vis_err; vis_err]);
title('Ne/ERN - visible-target - collapsed across error type');

% Pe
pimpfigure('ERP', [-100 600 -1.5 3.5], {'1' '1:' '3' '3:'}, ...
           {'correct social (N = 29)', 'correct nonsocial (N = 29)', 'error social (N = 26)', 'error nonsocial (N = 26)'}, ...
           [200 500], [vis_cor; vis_cor; vis_err; vis_err]);
title('Pe - visible-target - collapsed across error type');

%% difference waves
visual_comperp({'diffWave_soc_vis_error', 'diffWave_nonsoc_vis_error'}, ...
                char(diffWaves));

% ERN
pimpfigure('ERP', [-150 400 -2 2.5], {'1' '1:'}, ...
           {'error social (N = 26)', 'error nonsocial (N = 26)'}, ...
           [0 100], [vis_err; vis_err]);
title('∆ERN - visible-target - collapsed across error type');

% Pe
pimpfigure('ERP', [-100 600 -1.5 3.5], {'1' '1:'}, ...
           {'error social (N = 26)', 'error nonsocial (N = 26)'}, ...
           [200 500], [vis_err; vis_err]);
title('∆Pe - visible-target - collapsed across error type');



%% ========================================================================
%% INVISIBLE-TARGET
%% ========================================================================

%% grand averages
visual_comperp({'grandAVG_111_social_vis_corr', 'grandAVG_211_nonsoc_vis_corr', ...
                'grandAVG_102_social_invis_FE', 'grandAVG_202_nonsoc_invis_FE', ...
                'grandAVG_104_social_invis_NFG', 'grandAVG_204_nonsoc_invis_NFG'}, ...
                char(grandAver));

% ERN
pimpfigure('ERP', [-150 400 -2.5 3], {'1' '1:' '3' '3:' '5' '5:'}, ...
           {'vis-correct social', 'vis-correct nonsocial', 'FE social', 'FE nonsocial', 'NFG social', 'NFG nonsocial'}, ...
           [0 100], [vis_cor; vis_cor; invis_FE; invis_FE; invis_NFG; invis_NFG]);
title('Ne/ERN - invisible-target - grand averages');

% Pe
pimpfigure('ERP', [-100 600 -1.5 3.5], {'1' '1:' '3' '3:' '5' '5:'}, ...
           {'vis-correct social', 'vis-correct nonsocial', 'FE social', 'FE nonsocial', 'NFG social', 'NFG nonsocial'}, ...
           [200 500], [vis_cor; vis_cor; invis_FE; invis_FE; invis_NFG; invis_NFG]);
title('Pe - invisible-target - grand averages');

%% difference waves
visual_comperp({'diffWave_soc_invis_FE', 'diffWave_nonsoc_invis_FE', ...
                'diffWave_soc_invis_NFG', 'diffWave_nonsoc_invis_NFG'}, ...
                char(diffWaves));

% ERN
pimpfigure('ERP', [-150 400 -2 2.5], {'1' '1:' '3' '3:'}, ...
           {'FE social', 'FE nonsocial', 'NFG social', 'NFG nonsocial'}, ...
           [0 100], [invis_FE; invis_FE; invis_NFG; invis_NFG]);
title('∆ERN - invisible-target');

% Pe
pimpfigure('ERP', [-100 600 -1.5 3.5], {'1' '1:' '3' '3:'}, ...
           {'FE social', 'FE nonsocial', 'NFG social', 'NFG nonsocial'}, ...
           [200 500], [invis_FE; invis_FE; invis_NFG; invis_NFG]);
title('∆Pe - invisible-target');





%% MASTER LEGEND
figure('Position', [100 100 400 300]);
hold on;

% visible conditions
plot(NaN, NaN, '-', 'Color', vis_cor/255, 'LineWidth', 4); 
plot(NaN, NaN, ':', 'Color', vis_cor/255, 'LineWidth', 4);
plot(NaN, NaN, '-', 'Color', vis_FE/255, 'LineWidth', 4);
plot(NaN, NaN, ':', 'Color', vis_FE/255, 'LineWidth', 4);
plot(NaN, NaN, '-', 'Color', vis_NFE/255, 'LineWidth', 4);
plot(NaN, NaN, ':', 'Color', vis_NFE/255, 'LineWidth', 4);
plot(NaN, NaN, '-', 'Color', vis_err/255, 'LineWidth', 4);
plot(NaN, NaN, ':', 'Color', vis_err/255, 'LineWidth', 4);

% invisible conditions
plot(NaN, NaN, '-', 'Color', invis_NFG/255, 'LineWidth', 4);
plot(NaN, NaN, ':', 'Color', invis_NFG/255, 'LineWidth', 4);

legend({'Correct (nonsocial)', 'Correct (social)', ...
        'Flanker Error (nonsocial)', 'Flanker Error (social)', ...
        'Non-Flanker Error (nonsocial)', 'Non-Flanker Error (social)', ...
        'Error collapsed (nonsocial)', 'Error collapsed (social)', ...
        'Non-Flanker Guess (nonsocial)', 'Non-Flanker Guess (social)'}, ...
        'Location', 'bestoutside', 'FontSize', 12);
title('Legend - Line Types & Colors');
axis off;