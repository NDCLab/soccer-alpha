% main postprocessing batch script for SocCEr ERP analyses
% coordinates grand average making, difference waves & electrode cluster finding

% This script processes EEG data that has been preprocessed with the MADE pipeline
% and creates condition-specific grand averages based on behavioral codes

% author: Marlene Buch I 2025

clear; 
clc;

%% modular execution flags
run_grand_averages = false;      % step 1: make grand averages
run_difference_waves = false;    % step 2: compute difference waves  
run_electrode_clusters = true;  % step 3: find electrode clusters

% if running steps 2/3 without step 1, existing files will be loaded automatically

%% user input: define subject list & important codes

% slash-separated string of subject IDs to be processed in this run
subjects_to_process = "390011";

% convert subjects string to cell array
subjects_list = string(split(subjects_to_process, "/"));
subjects_list = subjects_list(subjects_list~=""); % remove empty entries
subjects = strcat("sub-", subjects_list); % add 'sub-' prefix
fprintf('subjects to process: %d total\n', length(subjects));

% trial codes (relevant for analyses only)
codes = [111, 112, 113, 102, 104, 211, 212, 213, 202, 204]; 

% code-to-name mapping for output files
code_names = containers.Map([111, 112, 113, 102, 104, 211, 212, 213, 202, 204], ...
    {'social-vis-corr', 'social-vis-FE', 'social-vis-NFE', 'social-invis-FE', 'social-invis-NFG', ...
     'nonsoc-vis-corr', 'nonsoc-vis-FE', 'nonsoc-vis-NFE', 'nonsoc-invis-FE', 'nonsoc-invis-NFG'});

% inclusion thresholds
min_epochs_threshold = 1;
min_accuracy_threshold = 0.6;

% RT trimming parameters
rt_lower_bound = 150; % ms, set to 0 if no lower bound
rt_outlier_threshold = 3; % standard deviations, set to 0 if no outlier trimming

% two-stage averaging options
save_individual_averages = true; % save individual subject averages per condition

% paths & directories
main_dir = 'C:/Users/localadmin/Documents/08_SocCEr/soccer-alpha';
processed_data_dir = fullfile(main_dir, 'input/preprocessed/s1_r1/eeg');
output_dir = fullfile(main_dir, 'derivatives/postprocessed/erp/resp-locked');

% create output directory if it doesn't exist
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
    fprintf('created output directory: %s\n', output_dir);
end

% define difference wave computations
diff_waves_table = [
    % visible condition: error - correct within social condition
    112, 111, "diffWave_soc-vis-FE";      % social visible flanker error - correct
    113, 111, "diffWave_soc_vis_NFE";     % social visible nonflanker error - correct  
    212, 211, "diffWave_nonsoc-vis-FE";   % nonsocial visible flanker error - correct
    213, 211, "diffWave_nonsoc-vis-NFE";  % nonsocial visible nonflanker error - correct
    
    % invisible condition: error/NFG - visible correct
    102, 111, "diffWave_soc-invis-FE";      % social invisible flanker error - social visible correct
    104, 111, "diffWave_soc-invis-NFG";     % social invisible NFG - social visible correct  
    202, 211, "diffWave_nonsoc-invis-FE";   % nonsocial invisible flanker error - nonsocial visible correct
    204, 211, "diffWave_nonsoc-invis-NFG"   % nonsocial invisible NFG - nonsocial visible correct
];

fprintf('defined %d difference wave computations\n', size(diff_waves_table, 1))

cluster_size = 3; % nr of electrodes in cluster, values from 1 to 5 are permissible
ern_time_window = [0, 100];
pe_time_window = [200, 500];

%% file paths for loading existing results
grand_avg_file = fullfile(output_dir, 'grand_averages', 'grand_averages.mat');
diff_waves_file = fullfile(output_dir, 'difference_waves', 'difference_waves.mat');

%% STEP 1: check inclusion criteria & make grand averages
if run_grand_averages
    fprintf('\n=== STEP 1: CHECKING INCLUSION & MAKING GRAND AVERAGES ===\n');
    fprintf('processing %d subjects for %d codes\n', length(subjects), length(code_names));
    
    % function call: 
    [included_subjects, grand_averages] = make_grand_averages(subjects, ...
        codes, min_epochs_threshold, min_accuracy_threshold, ...
        rt_lower_bound, rt_outlier_threshold, save_individual_averages, ...
        processed_data_dir, output_dir);
    
    fprintf('step 1 completed: %d/%d subjects included\n', length(included_subjects), length(subjects));
    
else
    % load existing grand averages if not running step 1
    if exist(grand_avg_file, 'file')
        fprintf('\n=== LOADING EXISTING GRAND AVERAGES ===\n');
        load(grand_avg_file, 'grand_averages', 'included_subjects');
        fprintf('loaded grand averages for %d subjects\n', length(included_subjects));
    else
        error('grand averages file not found: %s\nrun step 1 first or check file path', grand_avg_file);
    end
end

%% STEP 2: compute difference waves  
if run_difference_waves
    fprintf('\n=== STEP 2: COMPUTING DIFFERENCE WAVES ===\n');
    fprintf('computing configurable difference waves for ERP analyses\n');
    
    % function call
    difference_waves = compute_difference_waves(grand_averages, included_subjects, ...
        diff_waves_table, output_dir);
    
    fprintf('step 2 completed: difference waves computed\n');
    
else
    % load existing difference waves if not running step 2
    if exist(diff_waves_file, 'file')
        fprintf('\n=== LOADING EXISTING DIFFERENCE WAVES ===\n');
        load(diff_waves_file, 'difference_waves');
        fprintf('loaded difference waves\n');
    else
        error('difference waves file not found: %s\nrun step 2 first or check file path', diff_waves_file);
    end
end

%% STEP 3: find electrode clusters based on difference waves
if run_electrode_clusters
    fprintf('\n=== STEP 3: FINDING ELECTRODE CLUSTERS ===\n');  
    fprintf('identifying fronto-central (Ne/ERN) & centroparietal (Pe) electrode clusters\n');
    
    % function call
    electrode_clusters = find_electrode_clusters(difference_waves, output_dir, cluster_size, ern_time_window, pe_time_window);
    
    fprintf('step 3 completed: electrode clusters identified\n');
end

%% final summary
fprintf('\n=== POSTPROCESSING COMPLETE ===\n');
if exist('included_subjects', 'var')
    fprintf('included subjects: %d\n', length(included_subjects));
end
fprintf('output saved to: %s\n', output_dir);

% show what was run
steps_run = {};
if run_grand_averages, steps_run{end+1} = 'grand averages'; end
if run_difference_waves, steps_run{end+1} = 'difference waves'; end  
if run_electrode_clusters, steps_run{end+1} = 'electrode clusters'; end
fprintf('steps completed: %s\n', strjoin(steps_run, ', '));
fprintf('ready for statistical analysis!\n');