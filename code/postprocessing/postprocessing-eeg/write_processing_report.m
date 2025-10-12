function write_processing_report(processing_report, diff_waves_table, output_dir, report_file)
% write comprehensive processing summary report to text file
% 
% inputs:
%   processing_report - struct containing all processing metadata
%   diff_waves_table - table of difference wave computations
%   output_dir - main output directory path
%   report_file - full path to report file
%
% author: Marlene Buch I 2025

report_fid = fopen(report_file, 'w');

% header
fprintf(report_fid, '=== SOCCER ERP POSTPROCESSING SUMMARY REPORT ===\n');
fprintf(report_fid, 'generated: %s\n', datestr(processing_report.script_info.end_time));
fprintf(report_fid, 'script: %s\n', processing_report.script_info.name);
fprintf(report_fid, 'author: %s\n', 'Marlene Buch');
fprintf(report_fid, '\n');

% processing overview
fprintf(report_fid, '=== PROCESSING OVERVIEW ===\n');
fprintf(report_fid, 'start time: %s\n', datestr(processing_report.script_info.start_time));
fprintf(report_fid, 'end time: %s\n', datestr(processing_report.script_info.end_time));
fprintf(report_fid, 'total duration: %s\n', char(processing_report.script_info.total_duration));
fprintf(report_fid, 'output directory: %s\n', output_dir);
fprintf(report_fid, '\n');

% execution configuration
fprintf(report_fid, '=== EXECUTION CONFIGURATION ===\n');
fprintf(report_fid, 'step 1 (grand averages): %s\n', char(string(processing_report.execution_flags.run_grand_averages)));
fprintf(report_fid, 'step 2 (difference waves): %s\n', char(string(processing_report.execution_flags.run_difference_waves)));
fprintf(report_fid, 'step 3 (electrode clusters): %s\n', char(string(processing_report.execution_flags.run_electrode_clusters)));
fprintf(report_fid, '\n');

% input data
fprintf(report_fid, '=== INPUT DATA ===\n');
fprintf(report_fid, 'processed data directory: %s\n', processing_report.paths.processed_data_directory);
fprintf(report_fid, 'subjects requested: %d\n', processing_report.input_data.total_subjects_requested);
fprintf(report_fid, 'subject list: %s\n', strjoin(processing_report.input_data.subjects_requested, ', '));
fprintf(report_fid, 'codes processed: %s\n', mat2str(processing_report.input_data.codes_processed));
fprintf(report_fid, '\n');

% processing parameters
fprintf(report_fid, '=== PROCESSING PARAMETERS ===\n');
fprintf(report_fid, 'minimum epochs threshold: %d\n', processing_report.parameters.min_epochs_threshold);
fprintf(report_fid, 'minimum accuracy threshold: %.1f%%\n', processing_report.parameters.min_accuracy_threshold * 100);
fprintf(report_fid, 'RT lower bound: %d ms\n', processing_report.parameters.rt_lower_bound);
fprintf(report_fid, 'RT outlier threshold: %.1f SD\n', processing_report.parameters.rt_outlier_threshold);
fprintf(report_fid, 'save individual averages: %s\n', char(string(processing_report.parameters.save_individual_averages)));
fprintf(report_fid, 'ERN time window: %d-%d ms\n', processing_report.parameters.ern_time_window(1), processing_report.parameters.ern_time_window(2));
fprintf(report_fid, 'Pe time window: %d-%d ms\n', processing_report.parameters.pe_time_window(1), processing_report.parameters.pe_time_window(2));
fprintf(report_fid, '\n');

% step 1: grand averages
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

% step 2: difference waves
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

% step 3: electrode clusters
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

% output files
fprintf(report_fid, '=== OUTPUT FILES ===\n');
if processing_report.step1.executed || isfield(processing_report.step1, 'loaded_from_file')
    fprintf(report_fid, 'grand averages: %s\n', fullfile(output_dir, 'grand_averages'));
    fprintf(report_fid, '  - grand_averages.mat\n');
    fprintf(report_fid, '  - grand_averages_log_*.txt\n');
    fprintf(report_fid, '  - grandAVG_*.set/.fdt files\n');
    if processing_report.parameters.save_individual_averages
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

end