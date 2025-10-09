function [included_subjects, grand_averages] = make_grand_averages(subjects, codes, min_epochs_threshold, min_accuracy_threshold, rt_lower_bound, rt_outlier_threshold, save_individual_averages, processed_data_dir, output_dir)
% make_grand_averages - create condition-specific grand averages from preprocessed EEG data
%
% this function loads preprocessed EEGLAB .set files, checks inclusion criteria,
% applies RT trimming, and computes grand averages using two-stage averaging
%
% inputs:
%   subjects - cell array of subject IDs (e.g., {'sub-390011', 'sub-390012'})
%   codes - array of behavioral codes to process (e.g., [111, 112, 113, ...])
%   min_epochs_threshold - minimum epochs per code for inclusion (e.g., 10)
%   min_accuracy_threshold - minimum overall accuracy for inclusion (e.g., 0.6)
%   rt_lower_bound - minimum RT in ms (set to 0 to disable, e.g., 150)
%   rt_outlier_threshold - SD threshold for outlier trimming (set to 0 to disable, e.g., 3)
%   save_individual_averages - logical, save individual subject averages (true/false)
%   processed_data_dir - path to preprocessed .set files
%   output_dir - path to save grand averages
%
% outputs:
%   included_subjects - cell array of subjects meeting inclusion criteria
%   grand_averages - struct containing averaged data for each code
%
% author: Marlene Buch I 2025

fprintf('loading preprocessed EEG data & checking inclusion criteria...\n');

% define code-to-name mapping for output files (sorted by social condition)
code_names = containers.Map([111, 112, 113, 102, 104, 211, 212, 213, 202, 204], ...
    {'social-vis-corr', 'social-vis-FE', 'social-vis-NFE', 'social-invis-FE', 'social-invis-NFG', ...
     'nonsoc-vis-corr', 'nonsoc-vis-FE', 'nonsoc-vis-NFE', 'nonsoc-invis-FE', 'nonsoc-invis-NFG'});

% initialize outputs
included_subjects = {};
individual_averages = struct(); % store individual subject averages
subject_has_data = containers.Map('KeyType', 'char', 'ValueType', 'any'); % track which subjects have data for each code

% initialize logging structures
processing_stats = struct();

% create organized subdirectories
individual_dir = fullfile(output_dir, 'individual_averages');
grand_avg_dir = fullfile(output_dir, 'grand_averages');

% create individual averages directory if saving
if save_individual_averages
    if ~exist(individual_dir, 'dir')
        mkdir(individual_dir);
    end
end

% create grand averages directory
if ~exist(grand_avg_dir, 'dir')
    mkdir(grand_avg_dir);
end

%% stage 1: process each subject & create individual averages

fprintf('\n=== STAGE 1: INDIVIDUAL SUBJECT PROCESSING ===\n');

for subj_idx = 1:length(subjects)
    subject = subjects{subj_idx};
    fprintf('\n--- processing subject %s (%d/%d) ---\n', subject, subj_idx, length(subjects));
    
    % construct file path for this subject's processed data
    data_file = fullfile(processed_data_dir, subject, sprintf('%s_all_eeg_processed_data_s1_r1_e1.set', subject));
    
    % check if processed file exists
    if ~exist(data_file, 'file')
        fprintf('WARNING: processed file not found for %s, skipping\n', subject);
        continue;
    end
    
    % load preprocessed EEG data quietly
    try
        evalc('subject_EEG = pop_loadset(data_file);');
        evalc('subject_EEG = eeg_checkset(subject_EEG);');
        
        % ensure epoch field exists for RT processing
        if ~isfield(subject_EEG, 'epoch') || isempty(subject_EEG.epoch)
            fprintf('WARNING: no epoch information found for %s, skipping\n', subject);
            continue;
        end
        
        fprintf('loaded %d epochs from %d channels\n', subject_EEG.trials, subject_EEG.nbchan);
    catch ME
        fprintf('ERROR loading %s: %s\n', subject, ME.message);
        continue;
    end
    
    % process each code for this subject
    subject_clean = strrep(subject, '-', '_'); % for struct field names

    % count excluded trial types (responseType 7 & 8)
    all_response_types = [subject_EEG.epoch.trial_responseType];
    multiple_key_count = sum(all_response_types == 7);
    too_slow_count = sum(all_response_types == 8);

    % store in processing_stats
    processing_stats.(subject_clean).multiple_key_trials = multiple_key_count;
    processing_stats.(subject_clean).too_slow_trials = too_slow_count;
    processing_stats.(subject_clean).total_epochs_raw = subject_EEG.trials;

    fprintf('  excluded trials: %d multiple key, %d too slow\n', multiple_key_count, too_slow_count);

    % calculate overall accuracy for inclusion check
    all_codes_in_data = [subject_EEG.epoch.beh_code];
    visible_target_codes = [111, 112, 113, 211, 212, 213]; % visible condition trials
    visible_target_epochs = sum(ismember(all_codes_in_data, visible_target_codes));
    visible_error_codes = [112, 113, 212, 213]; % visible FE & NFE both conditions
    visible_error_epochs = sum(ismember(all_codes_in_data, visible_error_codes));
    overall_accuracy = 1 - (visible_error_epochs / visible_target_epochs);
    
    processing_stats.(subject_clean).total_epochs = visible_target_epochs;
    processing_stats.(subject_clean).overall_accuracy = overall_accuracy;
    
    fprintf('overall accuracy: %.1f%% (%d/%d visible trials)\n', overall_accuracy * 100, visible_target_epochs - visible_error_epochs, visible_target_epochs);
    
    % check accuracy inclusion criterion
    if overall_accuracy < min_accuracy_threshold
        fprintf('EXCLUDED: accuracy %.1f%% < threshold %.1f%%\n', overall_accuracy * 100, min_accuracy_threshold * 100);
        
        % still collect stats for excluded subjects (for table generation)
        for code = codes
            code_field = sprintf('code_%d', code);
            if ~isfield(processing_stats.(subject_clean), code_field)
                processing_stats.(subject_clean).(code_field) = struct('original', 0, 'after_rt_min', 0, 'after_outliers', 0, 'final', 0);
            end
        end
        
        continue;
    end
    
    % initialize individual averages structure for first subject
    if isempty(fieldnames(individual_averages))
        individual_averages.times = subject_EEG.times;
        individual_averages.chanlocs = subject_EEG.chanlocs;
        individual_averages.srate = subject_EEG.srate;
        individual_averages.nbchan = subject_EEG.nbchan;
        
        % initialize data arrays for each code
        for code = codes
            code_str = sprintf('code_%d', code);
            individual_averages.(code_str) = zeros(subject_EEG.nbchan, subject_EEG.pnts, length(subjects));
        end
    end
    
    % initialize subject as potential candidate
    meets_epochs_threshold = true;
    
    % collect trial info strings for compact output
    trial_info_strings = {};
    
    for code_idx = 1:length(codes)
        code = codes(code_idx);
        
        % find epochs for this code
        epoch_indices = find([subject_EEG.epoch.beh_code] == code);
        
        if isempty(epoch_indices)
            processing_stats.(subject_clean).(sprintf('code_%d', code)) = struct('original', 0, 'after_rt_min', 0, 'after_outliers', 0, 'final', 0);
            trial_info_strings{end+1} = sprintf('code %d: 0 epochs', code);
            meets_epochs_threshold = false;
            continue;
        end
        
        % apply RT trimming
        [cleaned_epochs, trial_stats] = trim_rt_outliers_with_stats(subject_EEG, epoch_indices, rt_lower_bound, rt_outlier_threshold);
        processing_stats.(subject_clean).(sprintf('code_%d', code)) = trial_stats;
        
        % create trial info string
        if trial_stats.original > trial_stats.final
            trial_info_strings{end+1} = sprintf('code %d: %d → %d epochs', code, trial_stats.original, trial_stats.final);
        else
            trial_info_strings{end+1} = sprintf('code %d: %d epochs', code, trial_stats.final);
        end
        
        % check minimum epochs threshold
        if length(cleaned_epochs) < min_epochs_threshold
            meets_epochs_threshold = false;
        end
        
        % average epochs for this code
        if ~isempty(cleaned_epochs)
            code_str = sprintf('code_%d', code);
            averaged_data = mean(subject_EEG.data(:, :, cleaned_epochs), 3);
            individual_averages.(code_str)(:, :, subj_idx) = averaged_data;
            
            % save individual average if requested (quietly)
            if save_individual_averages
                filename = sprintf('individualAVG_%s_%d_%s', subject, code, code_names(code));
                
                individual_EEG = eeg_emptyset();
                individual_EEG.data = averaged_data;
                individual_EEG.times = subject_EEG.times;
                individual_EEG.chanlocs = subject_EEG.chanlocs;
                individual_EEG.srate = subject_EEG.srate;
                individual_EEG.nbchan = subject_EEG.nbchan;
                individual_EEG.pnts = subject_EEG.pnts;
                individual_EEG.trials = 1;
                individual_EEG.xmin = subject_EEG.xmin;
                individual_EEG.xmax = subject_EEG.xmax;
                individual_EEG.setname = filename;
                individual_EEG.filename = [filename '.set'];
                
                evalc('individual_EEG = eeg_checkset(individual_EEG);');
                evalc('pop_saveset(individual_EEG, ''filename'', [filename ''.set''], ''filepath'', individual_dir);');
            end
        end
    end
    
    % print compact trial counts
    fprintf('%s\n', strjoin(trial_info_strings, '  '));
    
    % check if subject meets all inclusion criteria
    if meets_epochs_threshold
        included_subjects{end+1} = subject;
        fprintf('INCLUDED: %s (accuracy: %.1f%%)\n', subject, overall_accuracy * 100);
    else
        fprintf('EXCLUDED: insufficient epochs for one or more codes\n');
    end
    
end % end subject loop

%% stage 2: create grand averages

fprintf('\n=== STAGE 2: GRAND AVERAGE CREATION ===\n');

% final summary of stage 1
fprintf('total subjects processed: %d\n', length(subjects));
fprintf('subjects included: %d\n', length(included_subjects));
fprintf('subjects excluded: %d\n', length(subjects) - length(included_subjects));

if isempty(included_subjects)
    fprintf('WARNING: no subjects met inclusion criteria!\n');
    grand_averages = struct();
    return;
end

fprintf('included subjects: %s\n', strjoin(included_subjects, ', '));

% create detailed log file
log_file = fullfile(grand_avg_dir, sprintf('grand_averages_log_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
log_fid = fopen(log_file, 'w');

% write log header
fprintf(log_fid, '=== GRAND AVERAGES PROCESSING LOG ===\n');
fprintf(log_fid, 'processing date: %s\n', datestr(now));
fprintf(log_fid, 'script: make_grand_averages.m\n');
fprintf(log_fid, 'parameters:\n');
fprintf(log_fid, '  - min_epochs_threshold: %d\n', min_epochs_threshold);
fprintf(log_fid, '  - min_accuracy_threshold: %.2f\n', min_accuracy_threshold);
fprintf(log_fid, '  - rt_lower_bound: %d ms\n', rt_lower_bound);
fprintf(log_fid, '  - rt_outlier_threshold: %.1f SD\n', rt_outlier_threshold);
fprintf(log_fid, '  - save_individual_averages: %s\n', mat2str(save_individual_averages));
fprintf(log_fid, '\n');
fprintf(log_fid, '=== INCLUSION SUMMARY ===\n');
fprintf(log_fid, 'total subjects processed: %d\n', length(subjects));
fprintf(log_fid, 'subjects included: %d\n', length(included_subjects));
fprintf(log_fid, 'subjects excluded: %d\n', length(subjects) - length(included_subjects));
fprintf(log_fid, 'included subjects: %s\n', strjoin(included_subjects, ', '));
fprintf(log_fid, '\n');

% write detailed trial statistics
fprintf(log_fid, '=== DETAILED TRIAL STATISTICS ===\n');
fprintf(log_fid, 'subject\tcode\toriginal\tafter_rt_min\tafter_outliers\tfinal\n');
for subj_idx = 1:length(included_subjects)
    subject = included_subjects{subj_idx};
    subject_clean = strrep(subject, '-', '_');
    
    for code = codes
        if isfield(processing_stats, subject_clean) && isfield(processing_stats.(subject_clean), sprintf('code_%d', code))
            stats = processing_stats.(subject_clean).(sprintf('code_%d', code));
            fprintf(log_fid, '%s\t%d\t%d\t%d\t%d\t%d\n', ...
                subject, code, stats.original, stats.after_rt_min, stats.after_outliers, stats.final);
        end
    end
end
fprintf(log_fid, '\n');

% initialize grand averages structure
grand_averages = struct();
grand_averages.times = individual_averages.times;
grand_averages.chanlocs = individual_averages.chanlocs;
grand_averages.srate = individual_averages.srate;
grand_averages.nbchan = individual_averages.nbchan;

% create grand averages for each code - SIMPLIFIED & FIXED
fprintf(log_fid, '=== GRAND AVERAGE CREATION ===\n');
for code_idx = 1:length(codes)
    code = codes(code_idx);
    code_str = sprintf('code_%d', code);
    
    fprintf('creating grand average for code %d...\n', code);
    fprintf(log_fid, 'code %d (%s):\n', code, code_names(code));
    
    % since all included subjects have data for all codes, just directly copy the data
    % no need for zero-filling or complex indexing - just use what's already there
    grand_averages.(code_str) = individual_averages.(code_str);
    
    num_subjects = size(individual_averages.(code_str), 3);
    fprintf('  stored data from %d subjects\n', num_subjects);
    fprintf(log_fid, '  - subjects contributing to grand average: %d\n', num_subjects);
    fprintf(log_fid, '  - data dimensions: [%d channels x %d timepoints x %d subjects]\n', ...
        size(individual_averages.(code_str), 1), size(individual_averages.(code_str), 2), num_subjects);
end
fprintf(log_fid, '\n');

% write grand average summary statistics
fprintf(log_fid, '=== GRAND AVERAGE SUMMARY ===\n');
total_trials_original = 0;
total_trials_after_rt = 0;
total_trials_after_outliers = 0;
total_trials_final = 0;
total_correct_trials = 0;
total_epochs_all = 0;

for subj_idx = 1:length(included_subjects)
    subject = included_subjects{subj_idx};
    subject_clean = strrep(subject, '-', '_');
    
    % accumulate accuracy stats
    if isfield(processing_stats, subject_clean)
        accuracy = processing_stats.(subject_clean).overall_accuracy;
        epochs = processing_stats.(subject_clean).total_epochs;
        total_correct_trials = total_correct_trials + round(accuracy * epochs);
        total_epochs_all = total_epochs_all + epochs;
    end
    
    for code = codes
        if isfield(processing_stats, subject_clean) && isfield(processing_stats.(subject_clean), sprintf('code_%d', code))
            stats = processing_stats.(subject_clean).(sprintf('code_%d', code));
            total_trials_original = total_trials_original + stats.original;
            total_trials_after_rt = total_trials_after_rt + stats.after_rt_min;
            total_trials_after_outliers = total_trials_after_outliers + stats.after_outliers;
            total_trials_final = total_trials_final + stats.final;
        end
    end
end

trials_removed_rt = total_trials_original - total_trials_after_rt;
trials_removed_outliers = total_trials_after_rt - total_trials_after_outliers;
cumulative_accuracy = total_correct_trials / total_epochs_all;

fprintf(log_fid, 'cumulative accuracy across all included subjects:\n');
fprintf(log_fid, '  - total correct trials: %d\n', total_correct_trials);
fprintf(log_fid, '  - total trials (all): %d\n', total_epochs_all);
fprintf(log_fid, '  - cumulative accuracy: %.2f%%\n', cumulative_accuracy * 100);
fprintf(log_fid, '\n');
fprintf(log_fid, 'trial processing across all subjects & conditions:\n');
fprintf(log_fid, '  - original trials: %d\n', total_trials_original);
fprintf(log_fid, '  - trials removed (< %d ms): %d (%.1f%%)\n', rt_lower_bound, trials_removed_rt, ...
    100 * trials_removed_rt / total_trials_original);
fprintf(log_fid, '  - trials removed (outliers): %d (%.1f%%)\n', trials_removed_outliers, ...
    100 * trials_removed_outliers / total_trials_original);
fprintf(log_fid, '  - final trials used: %d (%.1f%%)\n', total_trials_final, ...
    100 * total_trials_final / total_trials_original);
fprintf(log_fid, '\n');

%% save grand averages in both formats

fprintf('\nsaving grand averages...\n');
fprintf(log_fid, '=== FILE OUTPUTS ===\n');

% save .mat file with all data in grand_averages subdirectory
mat_file = fullfile(grand_avg_dir, 'grand_averages.mat');
save(mat_file, 'grand_averages', 'included_subjects', 'codes', 'processing_stats');
fprintf(log_fid, 'saved .mat file: %s\n', mat_file);

% save individual .set/.fdt files for each code in grand_averages subdirectory (quietly)
fprintf(log_fid, 'saved .set/.fdt files:\n');
for code = codes
    code_str = sprintf('code_%d', code);
    if isfield(grand_averages, code_str)
        % create EEG structure for this code
        code_EEG = eeg_emptyset();
        code_EEG.data = mean(grand_averages.(code_str), 3); % average across subjects
        code_EEG.times = grand_averages.times;
        code_EEG.chanlocs = grand_averages.chanlocs;
        code_EEG.srate = grand_averages.srate;
        code_EEG.nbchan = grand_averages.nbchan;
        code_EEG.pnts = length(grand_averages.times);
        code_EEG.trials = 1;
        code_EEG.xmin = grand_averages.times(1) / 1000;
        code_EEG.xmax = grand_averages.times(end) / 1000;
        
        % set filename & save in grand_averages subdirectory
        filename = sprintf('grandAVG_%d_%s', code, code_names(code));
        code_EEG.setname = filename;
        code_EEG.filename = [filename '.set'];
        
        evalc('code_EEG = eeg_checkset(code_EEG);');
        evalc('pop_saveset(code_EEG, ''filename'', [filename ''.set''], ''filepath'', grand_avg_dir);');
        
        fprintf(log_fid, '  - %s.set/.fdt\n', filename);
    end
end

% close log file
fprintf(log_fid, '\n=== PROCESSING COMPLETED ===\n');
fprintf(log_fid, 'end time: %s\n', datestr(now));
fclose(log_fid);

fprintf('===========================\n');

end

function [cleaned_epochs, trial_stats] = trim_rt_outliers_with_stats(EEG, epoch_indices, rt_lower_bound, rt_outlier_threshold)
% trim_rt_outliers_with_stats - remove epochs based on RT criteria & track statistics

% initialize statistics
trial_stats = struct();
trial_stats.original = length(epoch_indices);

if isempty(epoch_indices)
    cleaned_epochs = [];
    trial_stats.after_rt_min = 0;
    trial_stats.after_outliers = 0;
    trial_stats.final = 0;
    return;
end

% extract RTs for this condition
epoch_rts = [EEG.epoch(epoch_indices).beh_flankerResp_rt] * 1000; % convert s to ms

% start with all epochs
keep_epochs = true(length(epoch_indices), 1);

% apply lower bound trimming
if rt_lower_bound > 0
    % ensure too_fast is a column vector to match keep_epochs
    too_fast = (epoch_rts < rt_lower_bound)';
    keep_epochs = keep_epochs & ~too_fast;
end

% track count after RT minimum trimming
trial_stats.after_rt_min = sum(keep_epochs);

% apply outlier trimming ONLY if there are enough trials left
if rt_outlier_threshold > 0 && sum(keep_epochs) > 1 % need at least 2 trials for stats
    rt_subset = epoch_rts(keep_epochs);
    rt_mean = mean(rt_subset);
    rt_std = std(rt_subset);
    
    % identify outliers in the remaining trials
    outliers_in_subset = abs(rt_subset - rt_mean) > (rt_outlier_threshold * rt_std);
    
    % map these outlier indices back to the original full list of epochs
    original_indices_to_keep = find(keep_epochs);
    outlier_original_indices = original_indices_to_keep(outliers_in_subset);
    
    % set these outlier epochs to false in the main keep_epochs vector
    keep_epochs(outlier_original_indices) = false;
end

% track final count after outlier removal
trial_stats.after_outliers = sum(keep_epochs);
trial_stats.final = sum(keep_epochs);

% return cleaned epoch indices
cleaned_epochs = epoch_indices(keep_epochs);

end