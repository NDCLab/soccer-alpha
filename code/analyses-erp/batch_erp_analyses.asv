% batch_erp_analyses.m
% main batch script for soccer erp analyses
% runs statistical analyses on erp components (ern & pe)
% uses testing_meanAmplitude for statistics & visual_comperp for visualization

function batch_erp_analyses(varargin)

clear; clc;

%% 1. setup & configuration
fprintf('\n=== SOCCER ERP ANALYSES ===\n');
fprintf('started: %s\n\n', datestr(now));

% load configuration with optional date
if nargin > 0
    cfg = config_erp_analyses(varargin{1});
else
    cfg = config_erp_analyses();  % uses most recent
end

% create output directories if needed
if ~exist(fullfile(cfg.output_path, 'tables'), 'dir')
    mkdir(fullfile(cfg.output_path, 'tables'));
end
if ~exist(fullfile(cfg.output_path, 'tables', 'visible-target'), 'dir')
    mkdir(fullfile(cfg.output_path, 'tables', 'visible-target'));
end
if ~exist(fullfile(cfg.output_path, 'tables', 'invisible-target'), 'dir')
    mkdir(fullfile(cfg.output_path, 'tables', 'invisible-target'));
end
if ~exist(fullfile(cfg.output_path, 'figures'), 'dir')
    mkdir(fullfile(cfg.output_path, 'figures'));
end
if ~exist(fullfile(cfg.output_path, 'figures', 'visible-target'), 'dir')
    mkdir(fullfile(cfg.output_path, 'figures', 'visible-target'));
end
if ~exist(fullfile(cfg.output_path, 'figures', 'invisible-target'), 'dir')
    mkdir(fullfile(cfg.output_path, 'figures', 'invisible-target'));
end
if ~exist(fullfile(cfg.output_path, 'logs'), 'dir')
    mkdir(fullfile(cfg.output_path, 'logs'));
end

% start logging
diary(fullfile(cfg.output_path, 'logs', sprintf('erp_analysis_%s.log', datestr(now, 'yyyy-mm-dd_HH-MM-SS'))));

%% 2. check data availability
fprintf('checking data files...\n');

% paths to key directories
diff_waves_dir = fullfile(cfg.derivatives_path, 'difference_waves');
grand_avg_dir = fullfile(cfg.derivatives_path, 'grand_averages');

% check if directories exist
if ~exist(diff_waves_dir, 'dir')
    error('difference waves directory not found: %s', diff_waves_dir);
end
if ~exist(grand_avg_dir, 'dir')
    error('grand averages directory not found: %s', grand_avg_dir);
end

fprintf('  difference waves: %s\n', diff_waves_dir);
fprintf('  grand averages: %s\n\n', grand_avg_dir);

%% 3. visible condition analyses
if cfg.run_visible
    fprintf('=== VISIBLE CONDITION ANALYSES ===\n\n');
    
    % define files for visible condition (all underscores)
    visible_files = {
        'diffWave_soc_vis_FE',      % social flanker error
        'diffWave_soc_vis_NFE',     % social non-flanker error  
        'diffWave_nonsoc_vis_FE',   % nonsocial flanker error
        'diffWave_nonsoc_vis_NFE'   % nonsocial non-flanker error
    };
    
    % labels for output
    visible_labels = {
        'soc_FE',
        'soc_NFE', 
        'nonsoc_FE',
        'nonsoc_NFE'
    };
    
    %% 3a. ern analysis - visible
    fprintf('analyzing ern component (0-100ms)...\n');
    
    % run testing_meanAmplitude for ern
    testing_meanAmplitude(diff_waves_dir, ...
        visible_files, ...
        visible_labels, ...
        fullfile(cfg.output_path, 'tables', 'visible-target', 'ern'), ...
        cfg.ern_window, ...
        cfg.ern_cluster, ...
        'ranova', table({'flanker'; 'nonflanker'; 'flanker'; 'nonflanker'}, ...
                       {'social'; 'social'; 'nonsocial'; 'nonsocial'}, ...
                       'VariableNames', {'error_type', 'social_condition'}));
    
    %% 3b. pe analysis - visible  
    fprintf('analyzing pe component (200-500ms)...\n');
    
    % run testing_meanAmplitude for pe
    testing_meanAmplitude(diff_waves_dir, ...
        visible_files, ...
        visible_labels, ...
        fullfile(cfg.output_path, 'tables', 'visible-target', 'pe'), ...
        cfg.pe_window, ...
        cfg.pe_cluster, ...
        'ranova', table({'flanker'; 'nonflanker'; 'flanker'; 'nonflanker'}, ...
                       {'social'; 'social'; 'nonsocial'; 'nonsocial'}, ...
                       'VariableNames', {'error_type', 'social_condition'}));
    
    %% 3c. visualization - visible
    if cfg.generate_plots
        fprintf('generating erp waveform plots...\n');
        
        % plot ern difference waves
        visual_comperp(visible_files, diff_waves_dir, ...
            'electrodeCluster', cfg.ern_cluster);
        title('ERN - Visible Condition');

        pimpfigure('ERP', ...
            [-200 600 -2 3], ...  % adjust y-limits based on your data
            {'b' 'b:' 'r' 'r:'}, ...  % blue solid/dotted for social, red for nonsocial
            {'Social FE', 'Social NFE', 'Nonsocial FE', 'Nonsocial NFE'}, ...
            cfg.ern_window);  % highlight ern analysis window

        % visual_comperp({'alt_grandAVG_CorrSilentInc' 'alt_grandAVG_CorrNoiseInc' 'alt_grandAVG_ErrSilentInc' 'alt_grandAVG_ErrNoiseInc' },folder,'channels',1:64);
        % pimpfigure('ERP', [-100 600 -1 19], {'1' '1:' '2' '2:'}, {'Correct Silent' 'Correct Noisy' 'Error Silent' 'Error Noisy'}, [0 100], [correct; error;]);

        % plot pe difference waves
        visual_comperp(visible_files, diff_waves_dir, ...
            'electrodeCluster', cfg.pe_cluster, ...
            'lowpass', cfg.lowpass_filter);
        title('Pe - Visible Condition');
    end
    
    fprintf('\nvisible condition analyses complete\n\n');
end

%% 4. invisible condition analyses
if cfg.run_invisible
    fprintf('=== INVISIBLE CONDITION ANALYSES ===\n\n');
    
    % define files for invisible condition (all underscores)
    invisible_files = {
        'diffWave_soc_invis_FE',     % social flanker error
        'diffWave_soc_invis_NFG',    % social non-flanker guess
        'diffWave_nonsoc_invis_FE',  % nonsocial flanker error
        'diffWave_nonsoc_invis_NFG'  % nonsocial non-flanker guess
    };
    
    % labels for output
    invisible_labels = {
        'soc_FE',
        'soc_NFG',
        'nonsoc_FE', 
        'nonsoc_NFG'
    };
    
    %% 4a. ern analysis - invisible
    fprintf('analyzing ern component (0-100ms)...\n');
    
    % run testing_meanAmplitude for ern
    testing_meanAmplitude(diff_waves_dir, ...
        invisible_files, ...
        invisible_labels, ...
        fullfile(cfg.output_path, 'tables', 'invisible-target', 'ern'), ...
        cfg.ern_window, ...
        cfg.ern_cluster, ...
        'ranova', table({'flanker_error'; 'nonflanker_guess'; 'flanker_error'; 'nonflanker_guess'}, ...
                       {'social'; 'social'; 'nonsocial'; 'nonsocial'}, ...
                       'VariableNames', {'response_type', 'social_condition'}));
    
    %% 4b. pe analysis - invisible
    fprintf('analyzing pe component (200-500ms)...\n');
    
    % run testing_meanAmplitude for pe
    testing_meanAmplitude(diff_waves_dir, ...
        invisible_files, ...
        invisible_labels, ...
        fullfile(cfg.output_path, 'tables', 'invisible-target', 'pe'), ...
        cfg.pe_window, ...
        cfg.pe_cluster, ...
        'ranova', table({'flanker_error'; 'nonflanker_guess'; 'flanker_error'; 'nonflanker_guess'}, ...
                       {'social'; 'social'; 'nonsocial'; 'nonsocial'}, ...
                       'VariableNames', {'response_type', 'social_condition'}));
    
    %% 4c. visualization - invisible
    if cfg.generate_plots
        fprintf('generating erp waveform plots...\n');
        
        % plot ern difference waves
        visual_comperp(invisible_files, diff_waves_dir, ...
            'electrodeCluster', cfg.ern_cluster, ...
            'lowpass', cfg.lowpass_filter);
        title('ERN - Invisible Condition');
        
        % plot pe difference waves
        visual_comperp(invisible_files, diff_waves_dir, ...
            'electrodeCluster', cfg.pe_cluster, ...
            'lowpass', cfg.lowpass_filter);
        title('Pe - Invisible Condition');
    end
    
    fprintf('\ninvisible condition analyses complete\n\n');
end

%% 5. finish up
fprintf('=== ANALYSES COMPLETE ===\n');
fprintf('results saved to: %s\n', cfg.output_path);
fprintf('finished: %s\n', datestr(now));

diary off;

end