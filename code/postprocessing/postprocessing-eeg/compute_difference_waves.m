function difference_waves = compute_difference_waves(grand_averages, included_subjects, diff_waves_table, output_dir, condition_inclusion, codes)
% compute_difference_waves - create configurable difference waves for ERP analysis
%
% this function computes difference waves based on user-defined table
%
% inputs:
%   grand_averages - struct from make_grand_averages containing averaged data
%   included_subjects - cell array of included subject IDs
%   diff_waves_table - matrix [minuend_code, subtrahend_code, wave_name]
%   output_dir - path to save difference waves
%
% outputs:
%   difference_waves - struct containing computed difference waves
%
% author: Marlene Buch I 2025

fprintf('computing difference waves...\n');

% create organized subdirectories
individual_dir = fullfile(output_dir, 'individual_averages');
grand_avg_dir = fullfile(output_dir, 'grand_averages');
diff_waves_dir = fullfile(output_dir, 'difference_waves');

% create directories if they don't exist
if ~exist(individual_dir, 'dir')
    mkdir(individual_dir);
    fprintf('created individual averages directory: %s\n', individual_dir);
end
if ~exist(grand_avg_dir, 'dir')
    mkdir(grand_avg_dir);
    fprintf('created grand averages directory: %s\n', grand_avg_dir);
end
if ~exist(diff_waves_dir, 'dir')
    mkdir(diff_waves_dir);
    fprintf('created difference waves directory: %s\n', diff_waves_dir);
end

% check if grand averages exist
if isempty(fieldnames(grand_averages))
    error('no grand averages provided - run make_grand_averages first');
end

% check if difference wave table provided
if isempty(diff_waves_table)
    error('no difference wave table provided');
end

if size(diff_waves_table, 2) ~= 3
    error('difference wave table must have 3 columns: minuend_code, subtrahend_code, wave_name');
end

% create detailed log file
log_file = fullfile(diff_waves_dir, sprintf('difference_waves_log_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
log_fid = fopen(log_file, 'w');

% write log header
fprintf(log_fid, '=== DIFFERENCE WAVES PROCESSING LOG ===\n');
fprintf(log_fid, 'processing date: %s\n', datestr(now));
fprintf(log_fid, 'script: compute_difference_waves.m\n');
fprintf(log_fid, 'included subjects: %d\n', length(included_subjects));
fprintf(log_fid, 'subjects: %s\n', strjoin(included_subjects, ', '));
fprintf(log_fid, '\n');

% initialize difference waves structure
difference_waves = struct();
difference_waves.times = grand_averages.times;
difference_waves.chanlocs = grand_averages.chanlocs;
difference_waves.srate = grand_averages.srate;
difference_waves.nbchan = grand_averages.nbchan;

fprintf('computing difference waves for %d included subjects\n', length(included_subjects));
fprintf(log_fid, '=== DIFFERENCE WAVE COMPUTATIONS ===\n');

% process each row in the difference wave table
num_waves = size(diff_waves_table, 1);
num_computed = 0;
num_skipped = 0;

for i = 1:num_waves
    minuend_code = double(diff_waves_table(i, 1));
    subtrahend_code = double(diff_waves_table(i, 2));
    wave_name = char(diff_waves_table(i, 3));

    % create valid field name by removing "diffWave_" prefix & replacing hyphens
    field_name = strrep(wave_name, 'diffWave_', '');
    field_name = strrep(field_name, '-', '_');

    fprintf('processing: %s\n', wave_name);
    fprintf(log_fid, 'difference wave: %s\n', wave_name);

    % check if required codes exist in grand averages
    minuend_field = sprintf('code_%d', minuend_code);
    subtrahend_field = sprintf('code_%d', subtrahend_code);

    if isfield(grand_averages, minuend_field) && isfield(grand_averages, subtrahend_field)
        % find code indices in codes array
        minuend_idx = find(codes == minuend_code);
        subtrahend_idx = find(codes == subtrahend_code);

        % determine which subjects have sufficient data in BOTH conditions
        subjects_for_this_diffwave = {};
        minuend_indices = [];
        subtrahend_indices = [];

        % for each included subject, check if they're in both grand averages
        for subj_idx = 1:length(included_subjects)
            subject = included_subjects{subj_idx};
            subject_inclusion = condition_inclusion(subject);

            % check if subject has both conditions
            if subject_inclusion(minuend_idx) && subject_inclusion(subtrahend_idx)
                subjects_for_this_diffwave{end+1} = subject;

                % find this subject's position in each grand average
                % count how many subjects before this one have the minuend code
                minuend_pos = 0;
                for i = 1:subj_idx
                    temp = condition_inclusion(included_subjects{i});
                    if temp(minuend_idx)
                        minuend_pos = minuend_pos + 1;
                    end
                end

                subtrahend_pos = 0;
                for i = 1:subj_idx
                    temp = condition_inclusion(included_subjects{i});
                    if temp(subtrahend_idx)
                        subtrahend_pos = subtrahend_pos + 1;
                    end
                end

                minuend_indices = [minuend_indices, minuend_pos];
                subtrahend_indices = [subtrahend_indices, subtrahend_pos];
            end
        end

        % compute difference only from subjects who have both conditions
        if ~isempty(minuend_indices)
            minuend_data = grand_averages.(minuend_field)(:, :, minuend_indices);
            subtrahend_data = grand_averages.(subtrahend_field)(:, :, subtrahend_indices);            difference_waves.(field_name) = minuend_data - subtrahend_data;
            num_computed = num_computed + 1;

            fprintf('  computed: %d - %d (%d subjects)\n', minuend_code, subtrahend_code, length(subjects_for_this_diffwave));
            fprintf(log_fid, '  - minuend: code %d\n', minuend_code);
            fprintf(log_fid, '  - subtrahend: code %d\n', subtrahend_code);
            fprintf(log_fid, '  - subjects: %d\n', length(subjects_for_this_diffwave));
            fprintf(log_fid, '  - subject list: %s\n', strjoin(subjects_for_this_diffwave, ', '));
            fprintf(log_fid, '  - field name: %s\n', field_name);
            fprintf(log_fid, '  - status: computed successfully\n');

            % log data dimensions
            dims = size(difference_waves.(field_name));
            fprintf(log_fid, '  - data dimensions: [%d channels x %d timepoints x %d subjects]\n', ...
                dims(1), dims(2), dims(3));
        else
            num_skipped = num_skipped + 1;
            warning('no subjects have sufficient data for both conditions in %s', wave_name);
            fprintf(log_fid, '  - minuend: code %d\n', minuend_code);
            fprintf(log_fid, '  - subtrahend: code %d\n', subtrahend_code);
            fprintf(log_fid, '  - subjects: 0 (no subjects with both conditions)\n');
            fprintf(log_fid, '  - status: SKIPPED - no valid subjects\n');
        end
    else
        % codes don't exist in grand averages
        num_skipped = num_skipped + 1;
        fprintf('  WARNING: missing data for %s (codes %d - %d)\n', wave_name, minuend_code, subtrahend_code);
        fprintf(log_fid, '  - minuend: code %d - %s\n', minuend_code, ifelse(isfield(grand_averages, minuend_field), 'available', 'MISSING'));
        fprintf(log_fid, '  - subtrahend: code %d - %s\n', subtrahend_code, ifelse(isfield(grand_averages, subtrahend_field), 'available', 'MISSING'));
        fprintf(log_fid, '  - status: SKIPPED - missing required data\n');
    end
    fprintf(log_fid, '\n');
end

%% save difference waves in both formats

fprintf('\nsaving difference waves...\n');
fprintf(log_fid, '=== FILE OUTPUTS ===\n');

% save .mat file with all difference waves
mat_file = fullfile(diff_waves_dir, 'difference_waves.mat');
save(mat_file, 'difference_waves', 'included_subjects', 'diff_waves_table');
fprintf('saved difference waves .mat file: %s\n', mat_file);
fprintf(log_fid, 'saved .mat file: %s\n', mat_file);

% save individual .set/.fdt files for each computed difference wave
fprintf(log_fid, 'saved .set/.fdt files:\n');
for i = 1:num_waves
    wave_name = char(diff_waves_table(i, 3));
    field_name = strrep(wave_name, 'diffWave_', '');
    field_name = strrep(field_name, '-', '_');

    % skip if this difference wave wasn't computed
    if ~isfield(difference_waves, field_name)
        continue;
    end

    % create EEG structure for this difference wave
    diff_EEG = eeg_emptyset();
    diff_EEG.data = difference_waves.(field_name);  % keep 3d structure - DON'T AVERAGE!

    % set proper dimensions
    num_subjects = size(difference_waves.(field_name), 3);
    diff_EEG.nbchan = size(difference_waves.(field_name), 1);
    diff_EEG.pnts = size(difference_waves.(field_name), 2);
    diff_EEG.trials = num_subjects;  % actual number of subjects, NOT 1

    % create event structure for each subject
    diff_EEG.event = [];
    for subj = 1:num_subjects
        diff_EEG.event(subj).type = field_name;
        diff_EEG.event(subj).latency = 1;
        diff_EEG.event(subj).epoch = subj;
        diff_EEG.event(subj).trials = subj;
        diff_EEG.event(subj).setname = sprintf('subject_%d', subj);  % generic subject names
    end

    % add timing & channel info
    diff_EEG.times = difference_waves.times;
    diff_EEG.chanlocs = difference_waves.chanlocs;
    diff_EEG.srate = difference_waves.srate;
    diff_EEG.xmin = difference_waves.times(1) / 1000;
    diff_EEG.xmax = difference_waves.times(end) / 1000;

    % use original wave_name for filename (includes "diffWave_" prefix)
    diff_EEG.setname = wave_name;
    diff_EEG.filename = [wave_name '.set'];

    diff_EEG = eeg_checkset(diff_EEG);
    pop_saveset(diff_EEG, 'filename', [wave_name '.set'], 'filepath', diff_waves_dir);

    fprintf('saved difference wave .set/.fdt files: %s\n', wave_name);
    fprintf(log_fid, '  - %s.set/.fdt\n', wave_name);
end

% write summary to log
fprintf(log_fid, '\n=== PROCESSING SUMMARY ===\n');
fprintf(log_fid, 'total difference waves requested: %d\n', num_waves);
fprintf(log_fid, 'difference waves computed: %d\n', num_computed);
fprintf(log_fid, 'difference waves skipped (missing data): %d\n', num_skipped);
fprintf(log_fid, 'difference waves saved in both .mat & .set/.fdt formats\n');

% summary to console
fprintf('\n=== DIFFERENCE WAVES SUMMARY ===\n');
fprintf('requested: %d difference waves\n', num_waves);
fprintf('computed: %d difference waves\n', num_computed);
fprintf('skipped: %d difference waves (missing data)\n', num_skipped);
fprintf('difference waves saved in both .mat & .set/.fdt formats\n');
fprintf('ready for electrode cluster identification\n');
fprintf('================================\n');

% close log file
fprintf(log_fid, '\n=== PROCESSING COMPLETED ===\n');
fprintf(log_fid, 'end time: %s\n', datestr(now));
fclose(log_fid);

fprintf('detailed log saved to: %s\n', log_file);

end

% helper function for conditional string output in logging
function result = ifelse(condition, true_val, false_val)
if condition
    result = true_val;
else
    result = false_val;
end
end