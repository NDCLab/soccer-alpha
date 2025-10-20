function [included_subjects, grand_averages] = make_grand_averages(subjects, codes, min_trials_per_code, min_accuracy_threshold, rt_lower_bound, rt_outlier_threshold, save_individual_averages, processed_data_dir, output_dir)
% make_grand_averages - create condition-specific grand averages from preprocessed EEG data
%
% this function loads preprocessed EEGLAB .set files, checks inclusion criteria,
% applies RT trimming, and computes grand averages using two-stage averaging
%
% inputs:
%   subjects - cell array of subject IDs (e.g., {'sub-390011', 'sub-390012'})
%   codes - array of behavioral codes to process (e.g., [111, 112, 113, ...])
%   min_trials_per_code - struct with per-code minimum trial thresholds (e.g., min_trials_per_code.code_111 = 10)
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
code_names = containers.Map([111, 112, 113, 102, 104, 211, 212, 213, 202, 204, 110, 210], ...
    {'social_vis_corr', 'social_vis_FE', 'social_vis_NFE', 'social_invis_FE', 'social_invis_NFG', ...
     'nonsoc_vis_corr', 'nonsoc_vis_FE', 'nonsoc_vis_NFE', 'nonsoc_invis_FE', 'nonsoc_invis_NFG', ...
     'social_vis_error', 'nonsoc_vis_error'});

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

% define primary hypothesis codes - subjects must have >= min_epochs_threshold in ALL of these
primary_codes = [102, 104, 202, 204];

% track which subjects have sufficient data for each code
% rows = subjects, columns = codes
condition_inclusion = containers.Map('KeyType', 'char', 'ValueType', 'any');

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

    % construct path to behavioral csv
    beh_file = fullfile(fileparts(fileparts(processed_data_dir)), 's1_r1', 'behavior', subject, sprintf('%s_soccer-test_psychopy_s1_r1_e1_clean.csv', subject));

    total_beh_trials = 0;
    actual_too_slow_count = 0;

    if exist(beh_file, 'file')
        try
            beh_data = readtable(beh_file);
            total_beh_trials = height(beh_data);

            % check for expected trial count
            if total_beh_trials ~= 864
                fprintf('WARNING: %s has %d behavioral trials, expected 864\n', subject, total_beh_trials);
            end

            % count too-slow trials (responseType == 8)
            if ismember('responseType', beh_data.Properties.VariableNames)
                actual_too_slow_count = sum(beh_data.responseType == 8);
                fprintf('  behavioral data: %d total trials, %d too-slow trials\n', total_beh_trials, actual_too_slow_count);
            else
                fprintf('WARNING: responseType column not found in behavioral data\n');
            end
        catch ME
            fprintf('WARNING: could not read behavioral file: %s\n', ME.message);
        end
    else
        fprintf('WARNING: behavioral file not found: %s\n', beh_file);
    end
    
    % process each code for this subject
    subject_clean = strrep(subject, '-', '_'); % for struct field names

    % count excluded trial types (responseType 7 & 8)
    all_response_types = [subject_EEG.epoch.trial_responseType];
    multiple_key_count = sum(all_response_types == 7);
    too_slow_count = sum(all_response_types == 8);  % note: too-slow trials are not epoched, this will always be 0

    % store in processing_stats
    processing_stats.(subject_clean).multiple_key_trials = multiple_key_count;
    processing_stats.(subject_clean).too_slow_trials = actual_too_slow_count;  % use actual count from behavioral data
    processing_stats.(subject_clean).total_beh_trials = total_beh_trials;
    processing_stats.(subject_clean).total_epochs_raw = subject_EEG.trials;

    fprintf('  excluded trials: %d multiple key, %d too slow (from behavioral data)\n', multiple_key_count, actual_too_slow_count);

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

        % don't pre-allocate - we'll build dynamically for included subjects only
        for code = codes
            code_str = sprintf('code_%d', code);
            individual_averages.(code_str) = [];
        end
    end

    % check primary hypothesis codes first (all-or-nothing for dataset inclusion)
    primary_codes = [102, 104, 202, 204];
    passes_primary_check = true;
    failed_primary_codes = [];
    
    % collect trial info strings for compact output
    trial_info_strings = {};
    
    for code_idx = 1:length(codes)
        code = codes(code_idx);
        
        % find epochs for this code
        if code == 110
            % combine trials from codes 112 & 113
            epoch_indices = find(ismember([subject_EEG.epoch.beh_code], [112, 113]));
        elseif code == 210
            % combine trials from codes 212 & 213
            epoch_indices = find(ismember([subject_EEG.epoch.beh_code], [212, 213]));
        else
            epoch_indices = find([subject_EEG.epoch.beh_code] == code);
        end
        
        if isempty(epoch_indices)
            processing_stats.(subject_clean).(sprintf('code_%d', code)) = struct('original', 0, 'after_rt_min', 0, 'after_outliers', 0, 'final', 0);
            trial_info_strings{end+1} = sprintf('code %d: 0 epochs', code);
            % check if this is a primary code
            if ismember(code, primary_codes)
                passes_primary_check = false;
                failed_primary_codes = [failed_primary_codes, code];
            end
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

        % check minimum epochs threshold for this specific code
        code_field = sprintf('code_%d', code);
        if isfield(min_trials_per_code, code_field)
            threshold_for_this_code = min_trials_per_code.(code_field);
        else
            threshold_for_this_code = 10; % default fallback
        end

        if length(cleaned_epochs) < threshold_for_this_code
            % check if this is a primary code
            if ismember(code, primary_codes)
                passes_primary_check = false;
                failed_primary_codes = [failed_primary_codes, code];
            end
        end
        
        % average epochs for this code
        if ~isempty(cleaned_epochs)
            code_str = sprintf('code_%d', code);
            averaged_data = mean(subject_EEG.data(:, :, cleaned_epochs), 3);
            
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

    % check if subject meets primary inclusion criteria
    if passes_primary_check
        included_subjects{end+1} = subject;
        fprintf('INCLUDED: %s (accuracy: %.1f%%)\n', subject, overall_accuracy * 100);

        % track which codes this subject has sufficient data for
        subject_code_inclusion = false(1, length(codes)); % initialize as all false
        for code_idx = 1:length(codes)
            code = codes(code_idx);
            code_field = sprintf('code_%d', code);

            % get threshold for this specific code
            if isfield(min_trials_per_code, code_field)
                threshold_for_this_code = min_trials_per_code.(code_field);
            else
                threshold_for_this_code = 10; % default fallback
            end

            if isfield(processing_stats.(subject_clean), code_field)
                % check if final count >= threshold for this code
                if processing_stats.(subject_clean).(code_field).final >= threshold_for_this_code
                    subject_code_inclusion(code_idx) = true;
                end
            end
        end

        % store this subject's code inclusion pattern
        condition_inclusion(subject) = subject_code_inclusion;

        % add subject data to individual_averages structure
        for code_idx = 1:length(codes)
            code = codes(code_idx);
            code_str = sprintf('code_%d', code);
            code_field = sprintf('code_%d', code);

            % check if subject has data for this code
            if isfield(processing_stats.(subject_clean), code_field) && processing_stats.(subject_clean).(code_field).final > 0
                % find epochs & compute average
                if code == 110
                    % combine trials from codes 112 & 113
                    epoch_indices = find(ismember([subject_EEG.epoch.beh_code], [112, 113]));
                elseif code == 210
                    % combine trials from codes 212 & 213
                    epoch_indices = find(ismember([subject_EEG.epoch.beh_code], [212, 213]));
                else
                    epoch_indices = find([subject_EEG.epoch.beh_code] == code);
                end
                [cleaned_epochs, ~] = trim_rt_outliers_with_stats(subject_EEG, epoch_indices, rt_lower_bound, rt_outlier_threshold);

                if ~isempty(cleaned_epochs)
                    averaged_data = mean(subject_EEG.data(:, :, cleaned_epochs), 3);
                    % append to individual_averages
                    individual_averages.(code_str) = cat(3, individual_averages.(code_str), averaged_data);
                end
            end
        end

    else
        % format failed codes for output
        failed_codes_str = sprintf('%d, ', failed_primary_codes);
        failed_codes_str = failed_codes_str(1:end-2); % remove trailing comma & space
        fprintf('EXCLUDED: insufficient epochs in primary conditions: %s\n', failed_codes_str);
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
fprintf(log_fid, '  - min_trials_per_code: varying by condition\n');
codes_list = fieldnames(min_trials_per_code);
for i = 1:length(codes_list)
    fprintf(log_fid, '    - %s: %d trials\n', codes_list{i}, min_trials_per_code.(codes_list{i}));
end
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

% create grand averages for each code
fprintf(log_fid, '=== GRAND AVERAGE CREATION ===\n');
for code_idx = 1:length(codes)
    code = codes(code_idx);
    code_str = sprintf('code_%d', code);
    
    fprintf('creating grand average for code %d...\n', code);
    fprintf(log_fid, 'code %d (%s):\n', code, code_names(code));
    
    % count subjects with sufficient data for this code
    subjects_for_this_code = {};
    subject_indices = [];
    
    for subj_idx = 1:length(included_subjects)
        subject = included_subjects{subj_idx};
        % get this subject's inclusion pattern & check this code
        subject_code_inclusion = condition_inclusion(subject);
        if subject_code_inclusion(code_idx)
            subjects_for_this_code{end+1} = subject;
            subject_indices = [subject_indices, subj_idx];
        end
    end
    
    % extract only those subjects' data
    if ~isempty(subject_indices)
        grand_averages.(code_str) = individual_averages.(code_str)(:, :, subject_indices);
    else
        grand_averages.(code_str) = [];
    end
    
    num_subjects = length(subjects_for_this_code);
    fprintf('  stored data from %d subjects\n', num_subjects);
    fprintf(log_fid, '  - subjects contributing: %d\n', num_subjects);
    fprintf(log_fid, '  - subject list: %s\n', strjoin(subjects_for_this_code, ', '));
    % store which subjects are in this grand average for difference waves
    grand_averages.subjects_per_code.(code_str) = subjects_for_this_code;
    if ~isempty(subject_indices)
        fprintf(log_fid, '  - data dimensions: [%d channels x %d timepoints x %d subjects]\n', ...
            size(grand_averages.(code_str), 1), size(grand_averages.(code_str), 2), num_subjects);
    end
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
save(mat_file, 'grand_averages', 'included_subjects', 'codes', 'processing_stats', 'condition_inclusion', 'min_trials_per_code');
fprintf(log_fid, 'saved .mat file: %s\n', mat_file);

% save individual .set/.fdt files for each code in grand_averages subdirectory (quietly)
fprintf(log_fid, 'saved .set/.fdt files:\n');
for code = codes
    code_str = sprintf('code_%d', code);
    if isfield(grand_averages, code_str)
        % create EEG structure for this code
        code_EEG = eeg_emptyset();
        code_EEG.data = grand_averages.(code_str);  % keep 3d structure
        
        % add proper dimensions
        num_subjects = size(grand_averages.(code_str), 3);
        code_EEG.nbchan = size(grand_averages.(code_str), 1);
        code_EEG.pnts = size(grand_averages.(code_str), 2);
        code_EEG.trials = num_subjects;  % number of subjects, NOT 1
        
        % create event structure for each subject
        code_EEG.event = [];
        for subj = 1:num_subjects
            code_EEG.event(subj).type = code_str;
            code_EEG.event(subj).latency = 1;
            code_EEG.event(subj).epoch = subj;
            code_EEG.event(subj).trials = subj;
            code_EEG.event(subj).setname = included_subjects{subj};
        end
        
        % add timing & channel info
        code_EEG.times = grand_averages.times;
        code_EEG.chanlocs = grand_averages.chanlocs;
        code_EEG.srate = grand_averages.srate;
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