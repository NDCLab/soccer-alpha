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
subjects_to_process = "390001/390002/390003/390004/390005/390006/390007/390008/390009/390010/390011/390012/390013/390014/390015/390020/390021/390023/390024/390025/390026/390027/390028/390030/390031/390032/390033/390034/390036/390037/390038/390039";

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
    processing_report.step1.subjects_excluded = setdiff(subjects, included_subjects);
    processing_report.step1.total_included = length(included_subjects);
    processing_report.step1.total_excluded = length(subjects) - length(included_subjects);
    processing_report.step1.inclusion_rate = length(included_subjects) / length(subjects);
    
    fprintf('step 1 completed: %d/%d subjects included\n', length(included_subjects), length(subjects));
    
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
    fprintf('computing configurable difference waves for ERP analyses\n');
    
    % function call
    difference_waves = compute_difference_waves(grand_averages, included_subjects, ...
        diff_waves_table, output_dir);
    
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

%% generate comprehensive processing summary report
processing_end_time = datetime('now');
processing_report.script_info.end_time = processing_end_time;
processing_report.script_info.total_duration = processing_end_time - processing_start_time;

% create comprehensive report file in main output directory
report_file = fullfile(output_dir, sprintf('postprocessing_summary_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
report_fid = fopen(report_file, 'w');

% write comprehensive report
fprintf(report_fid, '=== SOCCER ERP POSTPROCESSING SUMMARY REPORT ===\n');
fprintf(report_fid, 'generated: %s\n', datestr(processing_end_time));
fprintf(report_fid, 'script: %s\n', processing_report.script_info.name);
fprintf(report_fid, 'author: %s\n', 'Marlene Buch');
fprintf(report_fid, '\n');

fprintf(report_fid, '=== PROCESSING OVERVIEW ===\n');
fprintf(report_fid, 'start time: %s\n', datestr(processing_start_time));
fprintf(report_fid, 'end time: %s\n', datestr(processing_end_time));
fprintf(report_fid, 'total duration: %s\n', char(processing_report.script_info.total_duration));
fprintf(report_fid, 'output directory: %s\n', output_dir);
fprintf(report_fid, '\n');

fprintf(report_fid, '=== EXECUTION CONFIGURATION ===\n');
fprintf(report_fid, 'step 1 (grand averages): %s\n', char(string(run_grand_averages)));
fprintf(report_fid, 'step 2 (difference waves): %s\n', char(string(run_difference_waves)));
fprintf(report_fid, 'step 3 (electrode clusters): %s\n', char(string(run_electrode_clusters)));
fprintf(report_fid, '\n');

fprintf(report_fid, '=== INPUT DATA ===\n');
fprintf(report_fid, 'processed data directory: %s\n', processed_data_dir);
fprintf(report_fid, 'subjects requested: %d\n', processing_report.input_data.total_subjects_requested);
fprintf(report_fid, 'subject list: %s\n', strjoin(processing_report.input_data.subjects_requested, ', '));
fprintf(report_fid, 'codes processed: %s\n', mat2str(processing_report.input_data.codes_processed));
fprintf(report_fid, '\n');

fprintf(report_fid, '=== PROCESSING PARAMETERS ===\n');
fprintf(report_fid, 'minimum epochs threshold: %d\n', min_epochs_threshold);
fprintf(report_fid, 'minimum accuracy threshold: %.1f%%\n', min_accuracy_threshold * 100);
fprintf(report_fid, 'RT lower bound: %d ms\n', rt_lower_bound);
fprintf(report_fid, 'RT outlier threshold: %.1f SD\n', rt_outlier_threshold);
fprintf(report_fid, 'save individual averages: %s\n', char(string(save_individual_averages)));
fprintf(report_fid, 'ERN time window: %d-%d ms\n', ern_time_window(1), ern_time_window(2));
fprintf(report_fid, 'Pe time window: %d-%d ms\n', pe_time_window(1), pe_time_window(2));
fprintf(report_fid, '\n');

% step-specific results
if processing_report.step1.executed
    fprintf(report_fid, '=== STEP 1: GRAND AVERAGES ===\n');
    fprintf(report_fid, 'status: executed\n');
    fprintf(report_fid, 'duration: %s\n', char(processing_report.step1.duration));
    fprintf(report_fid, 'subjects included: %d/%d (%.1f%%)\n', ...
        processing_report.step1.total_included, ...
        processing_report.input_data.total_subjects_requested, ...
        processing_report.step1.inclusion_rate * 100);
    fprintf(report_fid, 'subjects excluded: %d\n', processing_report.step1.total_excluded);
    if ~isempty(processing_report.step1.subjects_excluded)
        fprintf(report_fid, 'excluded subjects: %s\n', strjoin(processing_report.step1.subjects_excluded, ', '));
    end
    fprintf(report_fid, 'included subjects: %s\n', strjoin(processing_report.step1.subjects_included, ', '));
else
    fprintf(report_fid, '=== STEP 1: GRAND AVERAGES ===\n');
    fprintf(report_fid, 'status: loaded from file\n');
    fprintf(report_fid, 'file: %s\n', processing_report.step1.loaded_from_file);
    fprintf(report_fid, 'subjects loaded: %d\n', processing_report.step1.total_included);
    fprintf(report_fid, 'included subjects: %s\n', strjoin(processing_report.step1.subjects_included, ', '));
end
fprintf(report_fid, '\n');

if processing_report.step2.executed
    fprintf(report_fid, '=== STEP 2: DIFFERENCE WAVES ===\n');
    fprintf(report_fid, 'status: executed\n');
    fprintf(report_fid, 'duration: %s\n', char(processing_report.step2.duration));
    fprintf(report_fid, 'difference waves computed: %d\n', processing_report.step2.total_difference_waves);
    fprintf(report_fid, 'computations requested: %d\n', size(diff_waves_table, 1));
    fprintf(report_fid, 'difference wave list:\n');
    for i = 1:size(diff_waves_table, 1)
        fprintf(report_fid, '  - %s: code %d - code %d\n', ...
            char(diff_waves_table(i, 3)), double(diff_waves_table(i, 1)), double(diff_waves_table(i, 2)));
    end
else
    fprintf(report_fid, '=== STEP 2: DIFFERENCE WAVES ===\n');
    fprintf(report_fid, 'status: loaded from file\n');
    fprintf(report_fid, 'file: %s\n', processing_report.step2.loaded_from_file);
    fprintf(report_fid, 'difference waves loaded: %d\n', processing_report.step2.total_difference_waves);
end
fprintf(report_fid, '\n');

if processing_report.step3.executed
    fprintf(report_fid, '=== STEP 3: ELECTRODE CLUSTERS ===\n');
    fprintf(report_fid, 'status: executed\n');
    fprintf(report_fid, 'duration: %s\n', char(processing_report.step3.duration));
    fprintf(report_fid, 'electrode clusters identified: %d\n', length(processing_report.step3.electrode_clusters_found));
    fprintf(report_fid, 'cluster types: %s\n', strjoin(processing_report.step3.electrode_clusters_found, ', '));
else
    fprintf(report_fid, '=== STEP 3: ELECTRODE CLUSTERS ===\n');
    fprintf(report_fid, 'status: not executed\n');
end
fprintf(report_fid, '\n');

fprintf(report_fid, '=== OUTPUT FILES ===\n');
if processing_report.step1.executed || isfield(processing_report.step1, 'loaded_from_file')
    fprintf(report_fid, 'grand averages: %s\n', fullfile(output_dir, 'grand_averages'));
    fprintf(report_fid, '  - grand_averages.mat\n');
    fprintf(report_fid, '  - grand_averages_log_*.txt\n');
    fprintf(report_fid, '  - grandAVG_*.set/.fdt files\n');
    if save_individual_averages
        fprintf(report_fid, '  - individualAVG_*.set/.fdt files\n');
    end
end

if processing_report.step2.executed || isfield(processing_report.step2, 'loaded_from_file')
    fprintf(report_fid, 'difference waves: %s\n', fullfile(output_dir, 'difference_waves'));
    fprintf(report_fid, '  - difference_waves.mat\n');
    fprintf(report_fid, '  - difference_waves_log_*.txt\n');
    fprintf(report_fid, '  - diffWave_*.set/.fdt files\n');
end

if processing_report.step3.executed
    fprintf(report_fid, 'electrode clusters: %s\n', output_dir);
    fprintf(report_fid, '  - electrode_clusters.mat\n');
    fprintf(report_fid, '  - electrode_clusters_summary.txt\n');
end

fprintf(report_fid, 'processing summary: %s\n', report_file);
fprintf(report_fid, '\n');

fprintf(report_fid, '=== PROCESSING COMPLETED SUCCESSFULLY ===\n');
fclose(report_fid);

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

% report file notification
fprintf('\ncomprehensive processing report saved to:\n%s\n', report_file);
fprintf('console log saved to:\n%s\n', console_log_file);
fprintf('ready for statistical analysis!\n');

%% close console logging
fprintf('\n=== SOCCER ERP POSTPROCESSING COMPLETED ===\n');
fprintf('session ended: %s\n', datestr(datetime('now')));
fprintf('total session duration: %s\n', char(processing_report.script_info.total_duration));
fprintf('===========================================\n');

diary off;