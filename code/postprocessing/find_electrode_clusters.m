function electrode_clusters = find_electrode_clusters(difference_waves, output_dir, ern_time_window, pe_time_window)
% find_electrode_clusters - identify ERN & Pe electrode clusters using maximal deflection-based selection
%
% this function identifies optimal electrode clusters for ERN and Pe based on:
% - maximal deflection identification within predefined electrode sets
% - cluster selection containing the maximal deflection electrode
% - mean amplitude comparison among eligible clusters
% - comprehensive reporting of all cluster options
%
% inputs:
%   difference_waves - struct from compute_difference_waves containing difference waves
%   output_dir - path to save results
%   ern_time_window - [start, end] in ms for ERN analysis (e.g., [0, 100])
%   pe_time_window - [start, end] in ms for Pe analysis (e.g., [200, 500])
%
% outputs:
%   electrode_clusters - struct containing ERN & Pe cluster evaluation results
%
% author: Marlene Buch I 2025

fprintf('identifying electrode clusters using maximal deflection-based selection...\n');
fprintf('ERN time window: %d-%d ms\n', ern_time_window(1), ern_time_window(2));
fprintf('Pe time window: %d-%d ms\n', pe_time_window(1), pe_time_window(2));

% check if difference waves exist
if isempty(fieldnames(difference_waves)) || ~isfield(difference_waves, 'times')
    error('no difference waves provided - run compute_difference_waves first');
end

%% step 1: average all visible condition difference waves for cluster selection

fprintf('\nstep 1: averaging visible condition difference waves for cluster selection\n');

% identify available visible condition difference waves
visible_waves = {};
visible_fields = {};

if isfield(difference_waves, 'soc_vis_FE')
    visible_waves{end+1} = difference_waves.soc_vis_FE;
    visible_fields{end+1} = 'soc_vis_FE';
end

if isfield(difference_waves, 'soc_vis_NFE')
    visible_waves{end+1} = difference_waves.soc_vis_NFE;
    visible_fields{end+1} = 'soc_vis_NFE';
end

if isfield(difference_waves, 'nonsoc_vis_FE')
    visible_waves{end+1} = difference_waves.nonsoc_vis_FE;
    visible_fields{end+1} = 'nonsoc_vis_FE';
end

if isfield(difference_waves, 'nonsoc_vis_NFE')
    visible_waves{end+1} = difference_waves.nonsoc_vis_NFE;
    visible_fields{end+1} = 'nonsoc_vis_NFE';
end

if isempty(visible_waves)
    error('no visible condition difference waves found for cluster selection');
end

fprintf('found %d visible condition difference waves: %s\n', length(visible_waves), strjoin(visible_fields, ', '));

% average visible waves across conditions & subjects
combined_visible_wave = zeros(size(visible_waves{1}, 1), size(visible_waves{1}, 2)); % 2D: channels x timepoints
for i = 1:length(visible_waves)
    % average across subjects (dimension 3) first, then add to combined wave
    wave_averaged = mean(visible_waves{i}, 3);
    combined_visible_wave = combined_visible_wave + wave_averaged;
end
combined_visible_wave = combined_visible_wave / length(visible_waves);

fprintf('combined visible difference wave created for cluster selection\n');

%% step 2: define predefined cluster options

fprintf('\nstep 2: defining predefined cluster options\n');

% predefined ERN cluster options
ern_cluster_options = {
    [1, 2, 5, 37, 34],    % option 1: 5 electrodes
    [1, 2, 34],           % option 2: 3 electrodes  
    [1, 2, 34, 33]        % option 3: 4 electrodes
};

% predefined Pe cluster options
pe_cluster_options = {
    [17, 18, 19, 50, 49], % option 1: 5 electrodes
    [17, 18, 49],         % option 2: 3 electrodes
    [33, 17, 18, 49],     % option 3: 4 electrodes
    [19, 50, 23]          % option 4: 3 electrodes
};

% extract unique electrodes for each ERP component
ern_electrodes = unique([ern_cluster_options{:}]);
pe_electrodes = unique([pe_cluster_options{:}]);

fprintf('defined %d ERN cluster options with electrodes [%s]\n', ...
    length(ern_cluster_options), strjoin(arrayfun(@num2str, ern_electrodes, 'UniformOutput', false), ', '));
fprintf('defined %d Pe cluster options with electrodes [%s]\n', ...
    length(pe_cluster_options), strjoin(arrayfun(@num2str, pe_electrodes, 'UniformOutput', false), ', '));

%% step 3: convert electrode labels to indices & define time windows

% find electrode indices in chanlocs
electrode_labels = {difference_waves.chanlocs.labels};

% convert ERN & Pe electrode sets to indices
ern_electrode_indices = zeros(1, length(ern_electrodes));
pe_electrode_indices = zeros(1, length(pe_electrodes));

for i = 1:length(ern_electrodes)
    idx = find(strcmp(electrode_labels, num2str(ern_electrodes(i))));
    if isempty(idx)
        error('electrode %d not found in channel locations', ern_electrodes(i));
    end
    ern_electrode_indices(i) = idx;
end

for i = 1:length(pe_electrodes)
    idx = find(strcmp(electrode_labels, num2str(pe_electrodes(i))));
    if isempty(idx)
        error('electrode %d not found in channel locations', pe_electrodes(i));
    end
    pe_electrode_indices(i) = idx;
end

% convert all cluster options to electrode indices
ern_cluster_indices = cell(size(ern_cluster_options));
pe_cluster_indices = cell(size(pe_cluster_options));

for i = 1:length(ern_cluster_options)
    cluster = ern_cluster_options{i};
    indices = zeros(1, length(cluster));
    for j = 1:length(cluster)
        idx = find(strcmp(electrode_labels, num2str(cluster(j))));
        if isempty(idx)
            error('electrode %d not found in channel locations', cluster(j));
        end
        indices(j) = idx;
    end
    ern_cluster_indices{i} = indices;
end

for i = 1:length(pe_cluster_options)
    cluster = pe_cluster_options{i};
    indices = zeros(1, length(cluster));
    for j = 1:length(cluster)
        idx = find(strcmp(electrode_labels, num2str(cluster(j))));
        if isempty(idx)
            error('electrode %d not found in channel locations', cluster(j));
        end
        indices(j) = idx;
    end
    pe_cluster_indices{i} = indices;
end

% define time windows (convert ms to sample indices)
times_ms = difference_waves.times;

ern_start_idx = find(times_ms >= ern_time_window(1), 1, 'first');
ern_end_idx = find(times_ms <= ern_time_window(2), 1, 'last');
pe_start_idx = find(times_ms >= pe_time_window(1), 1, 'first');
pe_end_idx = find(times_ms <= pe_time_window(2), 1, 'last');

fprintf('time windows - ERN: %d-%d ms (samples %d-%d), Pe: %d-%d ms (samples %d-%d)\n', ...
    ern_time_window(1), ern_time_window(2), ern_start_idx, ern_end_idx, ...
    pe_time_window(1), pe_time_window(2), pe_start_idx, pe_end_idx);

%% step 4: find maximal deflections within component-specific electrodes

fprintf('\nstep 4: finding maximal deflections within component-specific electrodes\n');

% find ERN maximal deflection (most negative) within ERN electrodes
ern_window_data = combined_visible_wave(ern_electrode_indices, ern_start_idx:ern_end_idx);
[max_ern_deflection, peak_idx] = min(ern_window_data(:));
[max_ern_electrode_idx, max_ern_time_idx] = ind2sub(size(ern_window_data), peak_idx);
max_ern_time = times_ms(ern_start_idx + max_ern_time_idx - 1);
max_ern_electrode = ern_electrodes(max_ern_electrode_idx);

fprintf('ERN maximal deflection: %.3f µV at electrode %d at %d ms\n', ...
    max_ern_deflection, max_ern_electrode, max_ern_time);

% find Pe maximal deflection (most positive) within Pe electrodes
pe_window_data = combined_visible_wave(pe_electrode_indices, pe_start_idx:pe_end_idx);
[max_pe_deflection, peak_idx] = max(pe_window_data(:));
[max_pe_electrode_idx, max_pe_time_idx] = ind2sub(size(pe_window_data), peak_idx);
max_pe_time = times_ms(pe_start_idx + max_pe_time_idx - 1);
max_pe_electrode = pe_electrodes(max_pe_electrode_idx);

fprintf('Pe maximal deflection: %.3f µV at electrode %d at %d ms\n', ...
    max_pe_deflection, max_pe_electrode, max_pe_time);

%% step 5: evaluate all clusters & identify eligible clusters

fprintf('\nstep 5: evaluating all clusters & identifying eligible clusters\n');

% evaluate all ERN clusters
[all_ern_evaluations, eligible_ern_clusters] = evaluate_all_clusters(combined_visible_wave, ...
    ern_cluster_options, ern_cluster_indices, ern_start_idx, ern_end_idx, ...
    max_ern_electrode, 'ERN', times_ms);

% evaluate all Pe clusters
[all_pe_evaluations, eligible_pe_clusters] = evaluate_all_clusters(combined_visible_wave, ...
    pe_cluster_options, pe_cluster_indices, pe_start_idx, pe_end_idx, ...
    max_pe_electrode, 'Pe', times_ms);

%% step 6: select best clusters from eligible options

fprintf('\nstep 6: selecting best clusters from eligible options\n');

% select best ERN cluster
if isempty(eligible_ern_clusters)
    error('no ERN clusters contain the maximal deflection electrode %d', max_ern_electrode);
end

best_ern_idx = select_best_cluster(all_ern_evaluations, eligible_ern_clusters, 'ERN');
best_ern_cluster = ern_cluster_options{best_ern_idx};
best_ern_evaluation = all_ern_evaluations{best_ern_idx};

fprintf('selected ERN cluster: option %d [%s] with %.3f µV mean amplitude\n', ...
    best_ern_idx, strjoin(arrayfun(@num2str, best_ern_cluster, 'UniformOutput', false), ', '), ...
    best_ern_evaluation.mean_amplitude);

% select best Pe cluster
if isempty(eligible_pe_clusters)
    error('no Pe clusters contain the maximal deflection electrode %d', max_pe_electrode);
end

best_pe_idx = select_best_cluster(all_pe_evaluations, eligible_pe_clusters, 'Pe');
best_pe_cluster = pe_cluster_options{best_pe_idx};
best_pe_evaluation = all_pe_evaluations{best_pe_idx};

fprintf('selected Pe cluster: option %d [%s] with %.3f µV mean amplitude\n', ...
    best_pe_idx, strjoin(arrayfun(@num2str, best_pe_cluster, 'UniformOutput', false), ', '), ...
    best_pe_evaluation.mean_amplitude);

%% step 7: create output structure

electrode_clusters = struct();

% ERN results
electrode_clusters.ERN.max_deflection_amplitude = max_ern_deflection;
electrode_clusters.ERN.max_deflection_time_ms = max_ern_time;
electrode_clusters.ERN.max_deflection_electrode = max_ern_electrode;
electrode_clusters.ERN.selected_cluster_electrodes = best_ern_cluster;
electrode_clusters.ERN.selected_cluster_electrodes_labels = arrayfun(@num2str, best_ern_cluster, 'UniformOutput', false);
electrode_clusters.ERN.selected_cluster_amplitude = best_ern_evaluation.mean_amplitude;
electrode_clusters.ERN.selected_cluster_peak_amplitude = best_ern_evaluation.peak_amplitude;
electrode_clusters.ERN.selected_cluster_peak_time_ms = best_ern_evaluation.peak_time;
electrode_clusters.ERN.selected_cluster_peak_electrode = best_ern_evaluation.peak_electrode;
electrode_clusters.ERN.time_window_ms = ern_time_window;
electrode_clusters.ERN.all_evaluations = all_ern_evaluations;
electrode_clusters.ERN.eligible_cluster_indices = eligible_ern_clusters;
electrode_clusters.ERN.selected_cluster_index = best_ern_idx;

% Pe results
electrode_clusters.Pe.max_deflection_amplitude = max_pe_deflection;
electrode_clusters.Pe.max_deflection_time_ms = max_pe_time;
electrode_clusters.Pe.max_deflection_electrode = max_pe_electrode;
electrode_clusters.Pe.selected_cluster_electrodes = best_pe_cluster;
electrode_clusters.Pe.selected_cluster_electrodes_labels = arrayfun(@num2str, best_pe_cluster, 'UniformOutput', false);
electrode_clusters.Pe.selected_cluster_amplitude = best_pe_evaluation.mean_amplitude;
electrode_clusters.Pe.selected_cluster_peak_amplitude = best_pe_evaluation.peak_amplitude;
electrode_clusters.Pe.selected_cluster_peak_time_ms = best_pe_evaluation.peak_time;
electrode_clusters.Pe.selected_cluster_peak_electrode = best_pe_evaluation.peak_electrode;
electrode_clusters.Pe.time_window_ms = pe_time_window;
electrode_clusters.Pe.all_evaluations = all_pe_evaluations;
electrode_clusters.Pe.eligible_cluster_indices = eligible_pe_clusters;
electrode_clusters.Pe.selected_cluster_index = best_pe_idx;

% metadata
electrode_clusters.method = 'maximal deflection-based cluster selection';
electrode_clusters.date_computed = datestr(now);
electrode_clusters.ern_electrodes = ern_electrodes;
electrode_clusters.pe_electrodes = pe_electrodes;

%% step 8: save results

% save electrode clusters
clusters_file = fullfile(output_dir, 'electrode_clusters.mat');
save(clusters_file, 'electrode_clusters');
fprintf('\nsaved electrode clusters: %s\n', clusters_file);

% save detailed summary text file
summary_file = fullfile(output_dir, 'electrode_clusters_summary.txt');
fid = fopen(summary_file, 'w');
fprintf(fid, '=== ELECTRODE CLUSTERS EVALUATION SUMMARY ===\n');
fprintf(fid, 'Date: %s\n', datestr(now));
fprintf(fid, 'Method: %s\n', electrode_clusters.method);
fprintf(fid, 'ERN electrodes considered: [%s]\n', ...
    strjoin(arrayfun(@num2str, ern_electrodes, 'UniformOutput', false), ', '));
fprintf(fid, 'Pe electrodes considered: [%s]\n\n', ...
    strjoin(arrayfun(@num2str, pe_electrodes, 'UniformOutput', false), ', '));

% maximal deflections
fprintf(fid, 'MAXIMAL DEFLECTIONS:\n');
fprintf(fid, 'ERN (0-100ms): %.3f µV at electrode %d at %d ms\n', ...
    max_ern_deflection, max_ern_electrode, max_ern_time);
fprintf(fid, 'Pe (200-500ms): %.3f µV at electrode %d at %d ms\n\n', ...
    max_pe_deflection, max_pe_electrode, max_pe_time);

% ERN evaluation details
fprintf(fid, 'ERN CLUSTER EVALUATIONS:\n');
fprintf(fid, 'Time window: %d-%d ms\n\n', ern_time_window(1), ern_time_window(2));
for i = 1:length(all_ern_evaluations)
    eval_data = all_ern_evaluations{i};
    contains_max = eval_data.contains_max_electrode;
    eligible_status = '';
    if contains_max
        eligible_status = ' [ELIGIBLE]';
    else
        eligible_status = ' [NOT ELIGIBLE - missing max deflection electrode]';
    end
    
    fprintf(fid, '  Option %d: [%s] (%d electrodes)%s\n', i, ...
        strjoin(arrayfun(@num2str, eval_data.electrodes, 'UniformOutput', false), ', '), ...
        length(eval_data.electrodes), eligible_status);
    fprintf(fid, '    Mean amplitude: %.3f µV\n', eval_data.mean_amplitude);
    fprintf(fid, '    Peak amplitude: %.3f µV at electrode %d at %d ms\n\n', ...
        eval_data.peak_amplitude, eval_data.peak_electrode, eval_data.peak_time);
end

fprintf(fid, '  SELECTED ERN CLUSTER: Option %d [%s]\n', ...
    best_ern_idx, strjoin(electrode_clusters.ERN.selected_cluster_electrodes_labels, ', '));
fprintf(fid, '    Mean amplitude: %.3f µV (most negative among eligible)\n', best_ern_evaluation.mean_amplitude);
fprintf(fid, '    Peak: %.3f µV at electrode %d at %d ms\n\n', ...
    best_ern_evaluation.peak_amplitude, best_ern_evaluation.peak_electrode, best_ern_evaluation.peak_time);

% Pe evaluation details  
fprintf(fid, 'Pe CLUSTER EVALUATIONS:\n');
fprintf(fid, 'Time window: %d-%d ms\n\n', pe_time_window(1), pe_time_window(2));
for i = 1:length(all_pe_evaluations)
    eval_data = all_pe_evaluations{i};
    contains_max = eval_data.contains_max_electrode;
    eligible_status = '';
    if contains_max
        eligible_status = ' [ELIGIBLE]';
    else
        eligible_status = ' [NOT ELIGIBLE - missing max deflection electrode]';
    end
    
    fprintf(fid, '  Option %d: [%s] (%d electrodes)%s\n', i, ...
        strjoin(arrayfun(@num2str, eval_data.electrodes, 'UniformOutput', false), ', '), ...
        length(eval_data.electrodes), eligible_status);
    fprintf(fid, '    Mean amplitude: %.3f µV\n', eval_data.mean_amplitude);
    fprintf(fid, '    Peak amplitude: %.3f µV at electrode %d at %d ms\n\n', ...
        eval_data.peak_amplitude, eval_data.peak_electrode, eval_data.peak_time);
end

fprintf(fid, '  SELECTED Pe CLUSTER: Option %d [%s]\n', ...
    best_pe_idx, strjoin(electrode_clusters.Pe.selected_cluster_electrodes_labels, ', '));
fprintf(fid, '    Mean amplitude: %.3f µV (most positive among eligible)\n', best_pe_evaluation.mean_amplitude);
fprintf(fid, '    Peak: %.3f µV at electrode %d at %d ms\n', ...
    best_pe_evaluation.peak_amplitude, best_pe_evaluation.peak_electrode, best_pe_evaluation.peak_time);

fclose(fid);
fprintf('saved detailed summary: %s\n', summary_file);

%% summary
fprintf('\n=== ELECTRODE CLUSTERS SELECTION COMPLETE ===\n');
fprintf('MAXIMAL DEFLECTIONS:\n');
fprintf('  ERN: %.3f µV at electrode %d at %d ms\n', max_ern_deflection, max_ern_electrode, max_ern_time);
fprintf('  Pe: %.3f µV at electrode %d at %d ms\n', max_pe_deflection, max_pe_electrode, max_pe_time);
fprintf('SELECTED CLUSTERS:\n');
fprintf('  ERN: option %d [%s] with %.3f µV mean amplitude\n', ...
    best_ern_idx, strjoin(electrode_clusters.ERN.selected_cluster_electrodes_labels, ', '), best_ern_evaluation.mean_amplitude);
fprintf('  Pe: option %d [%s] with %.3f µV mean amplitude\n', ...
    best_pe_idx, strjoin(electrode_clusters.Pe.selected_cluster_electrodes_labels, ', '), best_pe_evaluation.mean_amplitude);
fprintf('detailed evaluation data saved for documentation\n');
fprintf('================================\n');

end

%% helper function: evaluate all clusters & identify eligible ones
function [all_evaluations, eligible_indices] = evaluate_all_clusters(data, cluster_options, cluster_indices, ...
    start_idx, end_idx, max_electrode, component_name, times_ms)

fprintf('evaluating %d %s cluster options\n', length(cluster_options), component_name);

all_evaluations = {};
eligible_indices = [];

for i = 1:length(cluster_options)
    cluster = cluster_options{i};
    indices = cluster_indices{i};
    
    % check if cluster contains maximal deflection electrode
    contains_max = ismember(max_electrode, cluster);
    
    % extract data for this cluster in time window & compute mean amplitude
    cluster_data = data(indices, start_idx:end_idx);
    mean_amplitude = mean(cluster_data(:));
    
    % find peak within this cluster
    if strcmp(component_name, 'ERN')
        [cluster_peak_amp, peak_idx] = min(cluster_data(:));
    else % Pe
        [cluster_peak_amp, peak_idx] = max(cluster_data(:));
    end
    
    [peak_electrode_idx, peak_time_idx] = ind2sub(size(cluster_data), peak_idx);
    cluster_peak_time = times_ms(start_idx + peak_time_idx - 1);
    cluster_peak_electrode = cluster(peak_electrode_idx);
    
    % store evaluation data
    evaluation = struct();
    evaluation.electrodes = cluster;
    evaluation.mean_amplitude = mean_amplitude;
    evaluation.peak_amplitude = cluster_peak_amp;
    evaluation.peak_time = cluster_peak_time;
    evaluation.peak_electrode = cluster_peak_electrode;
    evaluation.contains_max_electrode = contains_max;
    all_evaluations{end+1} = evaluation;
    
    % track eligible clusters
    if contains_max
        eligible_indices(end+1) = i;
    end
    
    eligibility_note = '';
    if contains_max
        eligibility_note = ' [eligible]';
    else
        eligibility_note = ' [not eligible]';
    end
    
    fprintf('  option %d: [%s] = %.3f µV mean (peak: %.3f µV)%s\n', i, ...
        strjoin(arrayfun(@num2str, cluster, 'UniformOutput', false), ', '), ...
        mean_amplitude, cluster_peak_amp, eligibility_note);
end

fprintf('found %d eligible %s clusters containing electrode %d\n', ...
    length(eligible_indices), component_name, max_electrode);

end

%% helper function: select best cluster from eligible options
function best_idx = select_best_cluster(all_evaluations, eligible_indices, component_name)

best_amplitude = -inf; % will be overwritten
best_idx = eligible_indices(1); % fallback

for i = 1:length(eligible_indices)
    idx = eligible_indices(i);
    eval_data = all_evaluations{idx};
    mean_amplitude = eval_data.mean_amplitude;
    
    if strcmp(component_name, 'ERN')
        % for ERN: most negative mean amplitude
        if mean_amplitude < best_amplitude || i == 1
            best_amplitude = mean_amplitude;
            best_idx = idx;
        end
    else % Pe
        % for Pe: most positive mean amplitude
        if mean_amplitude > best_amplitude || i == 1
            best_amplitude = mean_amplitude;
            best_idx = idx;
        end
    end
end

end