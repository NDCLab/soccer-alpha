function print_console_summary(processing_report, output_dir, report_file, console_log_file)
% print final processing summary to console
%
% inputs:
%   processing_report - struct containing all processing metadata
%   output_dir - main output directory path
%   report_file - full path to detailed report file
%   console_log_file - full path to console log file
%
% author: Marlene Buch I 2025

fprintf('\n=== POSTPROCESSING COMPLETE ===\n');

% subjects processed
if isfield(processing_report.step1, 'subjects_included')
    fprintf('included subjects: %d\n', length(processing_report.step1.subjects_included));
end

fprintf('output saved to: %s\n', output_dir);

% steps completed
steps_run = {};
if processing_report.execution_flags.run_grand_averages
    steps_run{end+1} = 'grand averages';
end
if processing_report.execution_flags.run_difference_waves
    steps_run{end+1} = 'difference waves';
end
if processing_report.execution_flags.run_electrode_clusters
    steps_run{end+1} = 'electrode clusters';
end
fprintf('steps completed: %s\n', strjoin(steps_run, ', '));

% report file locations
fprintf('\ncomprehensive processing report saved to:\n%s\n', report_file);
fprintf('console log saved to:\n%s\n', console_log_file);
fprintf('ready for statistical analysis!\n');

% final session info
fprintf('\n=== SOCCER ERP POSTPROCESSING COMPLETED ===\n');
fprintf('session ended: %s\n', datestr(datetime('now')));
fprintf('total session duration: %s\n', char(processing_report.script_info.total_duration));
fprintf('===========================================\n');

end