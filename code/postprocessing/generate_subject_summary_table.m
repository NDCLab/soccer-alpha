function generate_subject_summary_table(processing_stats, included_subjects, codes, output_dir)
% generate tab-separated summary table for all subjects
% creates table matching format from google doc for easy copy-paste
%
% inputs:
%   processing_stats: structure with per-subject statistics
%   included_subjects: cell array of included subject IDs
%   codes: array of behavioral codes
%   output_dir: directory to save table
%
% author: Marlene Buch I 2025

fprintf('\n=== GENERATING SUBJECT SUMMARY TABLE ===\n');

% create output file
table_file = fullfile(output_dir, sprintf('subject_summary_table_%s.txt', datestr(now, 'yyyy-mm-dd_HH-MM-SS')));
fid = fopen(table_file, 'w');

% write header row (tab-separated, matching exact google doc format)
fprintf(fid, 'ID\tStatus\tExclusion Reason\tOverall Accuracy\tTotal Epochs Loaded\t');
fprintf(fid, 'Multiple Key (nr)\tMultiple Key (%%)\t');
fprintf(fid, 'Too Slow (nr)\tToo Slow (%%)\t');
fprintf(fid, 'RT Min Removed (nr)\tRT Min Removed (%%)\t');
fprintf(fid, 'RT Outliers Removed (nr)\tRT Outliers Removed (%%)\t');
fprintf(fid, 'Total Usable Epochs\t');
fprintf(fid, '111 (soc-vis-corr)\t112 (soc-vis-FE)\t113 (soc-vis-NFE)\tsum soc-vis-err\t');
fprintf(fid, '102 (soc-invis-FE)\t104 (soc-invis-NFG)\t');
fprintf(fid, '211 (nonsoc-vis-corr)\t212 (nonsoc-vis-FE)\t213 (nonsoc-vis-NFE)\tsum nonsoc-vis-err\t');
fprintf(fid, '202 (nonsoc-invis-FE)\t204 (nonsoc-invis-NFG)\t');
fprintf(fid, 'Lowest Trial Count\n');

% define column order (matching table structure)
column_order = [111, 112, 113, 102, 104, 211, 212, 213, 202, 204];

% get all subjects from processing_stats (includes both included & excluded)
all_subjects = fieldnames(processing_stats);

% process each subject
for subj_idx = 1:length(all_subjects)
    subject_clean = all_subjects{subj_idx};
    subject = strrep(subject_clean, '_', '-');  % convert back to original format
    subject_id = strrep(subject, 'sub-', '');
    
    % skip if no processing stats available
    if ~isfield(processing_stats, subject_clean)
        continue;
    end
    
    stats = processing_stats.(subject_clean);
    
    % extract basic info
    overall_acc = stats.overall_accuracy * 100;
    
    % get total raw epochs & excluded trial counts
    total_epochs_raw = stats.total_epochs_raw;
    multiple_key_trials = stats.multiple_key_trials;
    too_slow_trials = stats.too_slow_trials;
    
    % calculate total epochs loaded (sum of original across all analyzed codes)
    total_epochs = 0;
    for code = column_order
        code_field = sprintf('code_%d', code);
        if isfield(stats, code_field)
            total_epochs = total_epochs + stats.(code_field).original;
        end
    end
    
    % collect trial counts & removal statistics for each code
    code_data = struct();
    total_rt_min_removed = 0;  % trials removed due to RT < 150ms
    total_outliers_removed = 0;  % trials removed due to > 3SD per condition
    total_usable = 0;  % final trials after all removal
    
    for code = column_order
        code_field = sprintf('code_%d', code);
        
        if isfield(stats, code_field)
            code_stats = stats.(code_field);
            
            % store final count for this code
            code_data.(code_field).final = code_stats.final;
            total_usable = total_usable + code_stats.final;
            
            % calculate rt minimum removal for this code
            % (original trials - trials after rt minimum)
            rt_min_removed_this_code = code_stats.original - code_stats.after_rt_min;
            total_rt_min_removed = total_rt_min_removed + rt_min_removed_this_code;
            
            % calculate outlier removal for this code
            % outliers are calculated PER CODE (within-condition):
            % for each code separately, calculate mean & SD of RT
            % then remove trials > 3SD from that code's mean
            % here we sum the outliers across all codes
            outliers_this_code = code_stats.after_rt_min - code_stats.after_outliers;
            total_outliers_removed = total_outliers_removed + outliers_this_code;
        else
            code_data.(code_field).final = 0;
        end
    end
    
    % calculate removal percentages (denominator: total raw epochs)
    multiple_key_pct = (multiple_key_trials / total_epochs_raw) * 100;
    too_slow_pct = (too_slow_trials / total_epochs_raw) * 100;
    rt_min_removal_pct = (total_rt_min_removed / total_epochs_raw) * 100;
    outlier_removal_pct = (total_outliers_removed / total_epochs_raw) * 100;
    
    % calculate sum columns for error conditions
    soc_vis_err = code_data.code_112.final + code_data.code_113.final;
    nonsoc_vis_err = code_data.code_212.final + code_data.code_213.final;
    
    % find lowest trial count across all codes
    all_counts = [code_data.code_111.final, code_data.code_112.final, code_data.code_113.final, ...
                  code_data.code_102.final, code_data.code_104.final, ...
                  code_data.code_211.final, code_data.code_212.final, code_data.code_213.final, ...
                  code_data.code_202.final, code_data.code_204.final];
    lowest_trial_count = min(all_counts(all_counts > 0));
    if isempty(lowest_trial_count)
        lowest_trial_count = 0;
    end
    
    % write data row
    fprintf(fid, '%s\t', subject_id);
    fprintf(fid, '\t');  % status (blank)
    fprintf(fid, '\t');  % exclusion reason (blank)
    fprintf(fid, '%.1f%% (%d/%d)\t', overall_acc, round(overall_acc * total_epochs / 100), total_epochs);
    fprintf(fid, '%d\t', total_epochs_raw);
    
    % write exclusion statistics
    fprintf(fid, '%d\t', multiple_key_trials);
    fprintf(fid, '%.2f%%\t', multiple_key_pct);
    fprintf(fid, '%d\t', too_slow_trials);
    fprintf(fid, '%.2f%%\t', too_slow_pct);
    
    % write removal statistics
    fprintf(fid, '%d\t', total_rt_min_removed);
    fprintf(fid, '%.2f%%\t', rt_min_removal_pct);
    fprintf(fid, '%d\t', total_outliers_removed);
    fprintf(fid, '%.2f%%\t', outlier_removal_pct);
    fprintf(fid, '%d\t', total_usable);
    
    % write code counts in table order with sum columns inserted
    fprintf(fid, '%d\t', code_data.code_111.final);  % 111
    fprintf(fid, '%d\t', code_data.code_112.final);  % 112
    fprintf(fid, '%d\t', code_data.code_113.final);  % 113
    fprintf(fid, '%d\t', soc_vis_err);  % sum soc-vis-err
    fprintf(fid, '%d\t', code_data.code_102.final);  % 102
    fprintf(fid, '%d\t', code_data.code_104.final);  % 104
    fprintf(fid, '%d\t', code_data.code_211.final);  % 211
    fprintf(fid, '%d\t', code_data.code_212.final);  % 212
    fprintf(fid, '%d\t', code_data.code_213.final);  % 213
    fprintf(fid, '%d\t', nonsoc_vis_err);  % sum nonsoc-vis-err
    fprintf(fid, '%d\t', code_data.code_202.final);  % 202
    fprintf(fid, '%d\t', code_data.code_204.final);  % 204
    
    % write lowest trial count
    fprintf(fid, '%d\n', lowest_trial_count);
end

fclose(fid);

fprintf('subject summary table saved to:\n%s\n', table_file);
fprintf('ready to copy rows to google doc\n');

end