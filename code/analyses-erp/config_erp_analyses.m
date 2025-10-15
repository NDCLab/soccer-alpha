function cfg = config_erp_analyses(varargin)
% configuration settings for erp analyses
% usage: cfg = config_erp_analyses()           % uses most recent data
%        cfg = config_erp_analyses('2025-10-11') % uses specific date

    %% parse input
    if nargin > 0
        target_date = varargin{1};
    else
        target_date = [];  % will use most recent
    end
    
    %% paths
    cfg.project_root = fullfile('..', '..');
    derivatives_dir = fullfile(cfg.project_root, 'derivatives');
    
    %% find appropriate erp-postprocessing folder
    if ~isempty(target_date)
        % use specified date
        folder_name = sprintf('%s_erp-postprocessing', target_date);
        cfg.derivatives_path = fullfile(derivatives_dir, folder_name);
        
        % check if it exists
        if ~exist(cfg.derivatives_path, 'dir')
            error('no postprocessing data found for date: %s\nlooked in: %s', ...
                target_date, cfg.derivatives_path);
        end
        fprintf('using specified data from: %s\n', folder_name);
        
    else
        % find most recent folder
        folders = dir(fullfile(derivatives_dir, '*_erp-postprocessing'));
        
        if isempty(folders)
            error('no erp-postprocessing folders found in derivatives');
        end
        
        % sort by name (works because of yyyy-mm-dd format)
        folder_names = {folders.name};
        [~, idx] = sort(folder_names);
        most_recent = folders(idx(end)).name;
        
        cfg.derivatives_path = fullfile(derivatives_dir, most_recent);
        fprintf('using most recent data from: %s\n', most_recent);
    end
    
    %% output path
    cfg.output_path = fullfile(cfg.project_root, 'results', 'erp');
    
    %% time windows (in ms)
    cfg.ern_window = [0 100];      % ne/ern window
    cfg.pe_window = [200 500];     % pe window
    
    %% electrode clusters (using electrode numbers from cluster analysis)
    cfg.ern_cluster = [1, 2, 33, 34];     % selected ern cluster
    cfg.pe_cluster = [33, 17, 18, 49];    % selected pe cluster
    
    %% analysis settings
    cfg.run_visible = true;        % run visible target analyses
    cfg.run_invisible = true;      % run invisible target analyses
    cfg.generate_plots = true;     % generate erp waveform plots
    
    %% display settings for visual_comperp
    cfg.lowpass_filter = 30;       % hz for display
    cfg.baseline = [-200 0];       % baseline correction window
end