% batch script for ERP plotting
% coordinates visual ERP comparisons following the SocCEr analysis pipeline

clear; 
clc;

%% data source directories
grand_avg_dir = 'C:\Users\localadmin\Documents\08_SocCEr\soccer-dataset\derivatives\postprocessed\erp\resp-locked\grand_averages';
diff_waves_dir = 'C:\Users\localadmin\Documents\08_SocCEr\soccer-dataset\derivatives\postprocessed\erp\resp-locked\difference_waves';

%% create erp plots

% plot 1: compare social visible correct vs FE
visual_erp_comparison({'grandAVG_111_social-vis-corr', 'grandAVG_112_social-vis-FE'}, ...
    grand_avg_dir, 'channels', [1 2 34], 'minTrials', 0);

% plot 2: show difference wave with electrode cluster
visual_erp_comparison({'diffWave_soc-vis-FE'}, ...
    diff_waves_dir, 'electrodeCluster', [1 2 34], 'minTrials', 0);