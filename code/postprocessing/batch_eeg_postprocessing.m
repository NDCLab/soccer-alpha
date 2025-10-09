% main postprocessing batch script for SocCEr ERP analyses
% coordinates grand average making, difference waves & electrode cluster finding

% This script processes EEG data that has been preprocessed with the MADE pipeline
% and creates condition-specific grand averages based on behavioral codes

% author: Marlene Buch I 2025

clear; 
clc;

%% initialize comprehensive processing report
processing_start_time = datetime('now');
processing_report = struct();

%% setup logging - capture all console output to log file
today_str = datestr(now, 'yyyy-mm-dd');
temp_output_dir = fullfile('C:/Users/localadmin/Documents/08_SocCEr/soccer-alpha/derivatives', [today_str '_erp-postprocessing']);
if ~exist(temp_output_dir, 'dir')
    mkdir(temp_output_dir);
end

% create console log file & start diary
console_log_file = fullfile(temp_output_dir, sprintf('console_log_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
diary(console_log_file);
diary on;

fprintf('\n=== SOCCER ERP POSTPROCESSING STARTED ===\n');
fprintf('session started: %s\n', datestr(processing_start_time));
fprintf('console output logged to: %s\n', console_log_file);
fprintf('============================================\n\n');

%% modular execution flags
run_grand_averages = true;      % step 1: make grand averages
run_difference_waves = true;    % step 2: compute difference waves  
run_electrode_clusters = true;  % step 3: find electrode clusters

% if running steps 2/3 without step 1, existing files will be loaded automatically

%% user input: define subject list & important codes

% slash-separated string of subject IDs to be processed in this run
subjects_to_process = "390001/390002/390003/390004/390005/390006/390007/390008/390009/390010/390011/390012/390013/390014/390015/390020/390021/390022/390023/390024/390025/390026/390027/390028/390030/390031/390032/390033/390034/390036/390037/390038/390039/390040/390041/390042";

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
preprocessed_path_file = fullfile(main_dir, 'input/preprocessed');
preprocessed_path = strtrim(fileread(preprocessed_path_file));
processed_data_dir = fullfile(preprocessed_path, 's1_r1/eeg');

today_str = datestr(now, 'yyyy-mm-dd');
output_dir = fullfile(main_dir, 'derivatives', [today_str '_erp-postprocessing']);

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

fprintf('defined %d difference wave computations\n', size(diff_waves_table, 1));

ern_time_window = [0, 100];
pe_time_window = [200, 500];

%% store processing parameters in report structure
processing_report.script_info.name = 'batch_eeg_postprocessing.m';
processing_report.script_info.author = 'Marlene Buch';
processing_report.script_info.start_time = processing_start_time;

% execution flags
processing_report.execution_flags.run_grand_averages = run_grand_averages;
processing_report.execution_flags.run_difference_waves = run_difference_waves;
processing_report.execution_flags.run_electrode_clusters = run_electrode_clusters;

% subject & code information
processing_report.input_data.subjects_requested = subjects;
processing_report.input_data.total_subjects_requested = length(subjects);
processing_report.input_data.codes_processed = codes;
processing_report.input_data.code_names = code_names;

% processing parameters
processing_report.parameters.min_epochs_threshold = min_epochs_threshold;
processing_report.parameters.min_accuracy_threshold = min_accuracy_threshold;
processing_report.parameters.rt_lower_bound = rt_lower_bound;
processing_report.parameters.rt_outlier_threshold = rt_outlier_threshold;
processing_report.parameters.save_individual_averages = save_individual_averages;
processing_report.parameters.ern_time_window = ern_time_window;
processing_report.parameters.pe_time_window = pe_time_window;

% path information
processing_report.paths.main_directory = main_dir;
processing_report.paths.processed_data_directory = processed_data_dir;
processing_report.paths.output_directory = output_dir;

% difference wave configuration
processing_report.difference_waves.table = diff_waves_table;
processing_report.difference_waves.total_computations = size(diff_waves_table, 1);

%% file paths for loading existing results
grand_avg_file = fullfile(output_dir, 'grand_averages', 'grand_averages.mat');
diff_waves_file = fullfile(output_dir, 'difference_waves', 'difference_waves.mat');

%% STEP 1: check inclusion criteria & make grand averages
step1_start_time = datetime('now');
if run_grand_averages
    fprintf('\n=== STEP 1: CHECKING INCLUSION & MAKING GRAND AVERAGES ===\n');
    fprintf('processing %d subjects for %d codes\n', length(subjects), length(code_names));
    
    % function call: 
    [included_subjects, grand_averages] = make_grand_averages(subjects, ...
        codes, min_epochs_threshold, min_accuracy_threshold, ...
        rt_lower_bound, rt_outlier_threshold, save_individual_averages, ...
        processed_data_dir, output_dir);
    
    step1_end_time = datetime('now');
    
    % store step 1 results
    processing_report.step1.executed = true;
    processing_report.step1.start_time = step1_start_time;
    processing_report.step1.end_time = step1_end_time;
    processing_report.step1.duration = step1_end_time - step1_start_time;
    processing_report.step1.subjects_included = included_subjects;
    processing_report.step1.total_included = length(included_subjects);
    processing_report.step1.total_excluded = length(subjects) - length(included_subjects);
    processing_report.step1.inclusion_rate = length(included_subjects) / length(subjects);
    processing_report.step1.subjects_excluded = setdiff(subjects, included_subjects);
    
    fprintf('step 1 completed: grand averages created\n');
    
    % generate subject summary table
    fprintf('\ngenerating subject summary table...\n');
    grand_avg_data = load(grand_avg_file);
    generate_subject_summary_table(grand_avg_data.processing_stats, included_subjects, codes, output_dir);
    
else
    % load existing grand averages if not running step 1
    if exist(grand_avg_file, 'file')
        fprintf('\n=== LOADING EXISTING GRAND AVERAGES ===\n');
        load(grand_avg_file, 'grand_averages', 'included_subjects');
        fprintf('loaded grand averages for %d subjects\n', length(included_subjects));
        
        % store loading information
        processing_report.step1.executed = false;
        processing_report.step1.loaded_from_file = grand_avg_file;
        processing_report.step1.subjects_included = included_subjects;
        processing_report.step1.total_included = length(included_subjects);
    else
        error('grand averages file not found: %s\nrun step 1 first or check file path', grand_avg_file);
    end
end

%% STEP 2: compute difference waves
step2_start_time = datetime('now');
if run_difference_waves
    fprintf('\n=== STEP 2: COMPUTING DIFFERENCE WAVES ===\n');
    fprintf('computing %d difference waves\n', size(diff_waves_table, 1));
    
    % function call
    difference_waves = compute_difference_waves(grand_averages, included_subjects, diff_waves_table, output_dir);
    
    step2_end_time = datetime('now');
    
    % store step 2 results
    processing_report.step2.executed = true;
    processing_report.step2.start_time = step2_start_time;
    processing_report.step2.end_time = step2_end_time;
    processing_report.step2.duration = step2_end_time - step2_start_time;
    processing_report.step2.difference_waves_computed = fieldnames(difference_waves);
    processing_report.step2.total_difference_waves = length(fieldnames(difference_waves)) - 4; % subtract metadata fields
    
    fprintf('step 2 completed: difference waves computed\n');
    
else
    % load existing difference waves if not running step 2
    if exist(diff_waves_file, 'file')
        fprintf('\n=== LOADING EXISTING DIFFERENCE WAVES ===\n');
        load(diff_waves_file, 'difference_waves');
        fprintf('loaded difference waves\n');
        
        % store loading information  
        processing_report.step2.executed = false;
        processing_report.step2.loaded_from_file = diff_waves_file;
        processing_report.step2.difference_waves_computed = fieldnames(difference_waves);
        processing_report.step2.total_difference_waves = length(fieldnames(difference_waves)) - 4;
    else
        error('difference waves file not found: %s\nrun step 2 first or check file path', diff_waves_file);
    end
end

%% STEP 3: find electrode clusters based on difference waves
step3_start_time = datetime('now');
if run_electrode_clusters
    fprintf('\n=== STEP 3: FINDING ELECTRODE CLUSTERS ===\n');  
    fprintf('identifying fronto-central (Ne/ERN) & centroparietal (Pe) electrode clusters\n');
    
    % function call
    electrode_clusters = find_electrode_clusters(difference_waves, output_dir, ern_time_window, pe_time_window);
    
    step3_end_time = datetime('now');
    
    % store step 3 results
    processing_report.step3.executed = true;
    processing_report.step3.start_time = step3_start_time;
    processing_report.step3.end_time = step3_end_time;
    processing_report.step3.duration = step3_end_time - step3_start_time;
    processing_report.step3.electrode_clusters_found = fieldnames(electrode_clusters);
    
    fprintf('step 3 completed: electrode clusters identified\n');
else
    processing_report.step3.executed = false;
end

%% finalize & write reports
processing_end_time = datetime('now');
processing_report.script_info.end_time = processing_end_time;
processing_report.script_info.total_duration = processing_end_time - processing_start_time;

% generate comprehensive text report
report_file = fullfile(output_dir, sprintf('postprocessing_summary_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
write_processing_report(processing_report, diff_waves_table, output_dir, report_file);

% print console summary
print_console_summary(processing_report, output_dir, report_file, console_log_file);

%% close console logging
diary off;