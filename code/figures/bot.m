function fig_handle = visual_erp_comparison(filenames, data_dir, varargin)
% visual_erp_comparison() - plot ERP waves for comparison
% simplified version similar to visual_comperp.m
%
% usage: 
%   >> visual_erp_comparison(filenames, data_dir, optionalParameters)
% 
% mandatory inputs:
%   filenames   - cell array of .set files to be plotted
%   data_dir    - directory containing the .set files
%
% optional inputs:
%   'channels'        - electrodes to plot (numeric array or cell array)
%   'electrodeCluster' - average specified electrodes into single trace
%   'timeWindow'      - time range to display [start_ms end_ms]
%   'title'           - plot title
%   'gradient'        - display gradient instead of amplitude
%   'shading'         - add error shading (only works with multiple trials)
%
% author: [your name] I 2025

% parameter defaults
channels = [];
cluster = [];
timeWindow = [];
plotTitle = '';
gradientMode = false;
showShading = false;

% parse optional parameters
for i = 1:length(varargin)
    if strcmp(varargin{i}, 'channels') 
        if length(varargin) > i
            channels = varargin{i+1}; 
        end
    end
    if strcmp(varargin{i}, 'electrodeCluster')
        if length(varargin) > i
            cluster = varargin{i+1}; 
        end
    end
    if strcmp(varargin{i}, 'timeWindow')
        if length(varargin) > i
            timeWindow = varargin{i+1}; 
        end
    end
    if strcmp(varargin{i}, 'title')
        if length(varargin) > i
            plotTitle = varargin{i+1}; 
        end
    end
    if strcmp(varargin{i}, 'gradient')
        gradientMode = true;
    end
    if strcmp(varargin{i}, 'shading')
        showShading = true;
    end
end

% load data files
fprintf('loading %d files for ERP plotting\n', length(filenames));
for i = 1:length(filenames)
    file_path = fullfile(data_dir, filenames{i});
    if ~exist(file_path, 'file')
        error('file not found: %s', file_path);
    end
    
    fprintf('loading file %d: %s\n', i, filenames{i});
    data(i) = pop_loadset(file_path);
    data(i) = eeg_checkset(data(i));
end

% apply electrode clustering if specified (like visual_comperp does)
if ~isempty(cluster)
    fprintf('using electrode cluster: averaging channels\n');
    for iC = 1:length(data)
        % convert channel names/numbers to indices
        if iscell(cluster)
            channel_indices = [];
            for ch = 1:length(cluster)
                if isnumeric(cluster{ch}) || (ischar(cluster{ch}) && all(isstrprop(cluster{ch}, 'digit')))
                    channel_indices(end+1) = str2double(cluster{ch});
                else
                    ch_idx = find(strcmp({data(iC).chanlocs.labels}, cluster{ch}));
                    if ~isempty(ch_idx)
                        channel_indices(end+1) = ch_idx;
                    end
                end
            end
        else
            channel_indices = cluster;
        end
        
        % average ONLY the specified channels for THIS file
        dataCluster = mean(data(iC).data(channel_indices, :, :), 1);
        % replace only the first channel with the averaged data
        data(iC).data(1, :, :) = dataCluster;
        
        % update first channel label
        data(iC).chanlocs(1).labels = 'cluster_avg';
    end
end

% apply gradient if specified
if gradientMode
    fprintf('applying gradient transformation\n');
    for iData = 1:length(data)
        for iChannel = 1:size(data(iData).data, 1)
            for iTrial = 1:size(data(iData).data, 3)
                currData = data(iData).data(iChannel, :, iTrial);
                currData = gradient(currData);
                data(iData).data(iChannel, :, iTrial) = currData;
            end
        end     
    end
end

% restrict time window if specified
if ~isempty(timeWindow)
    fprintf('restricting to time window: %d to %d ms\n', timeWindow(1), timeWindow(2));
    for iData = 1:length(data)
        time_indices = find(data(iData).times >= timeWindow(1) & data(iData).times <= timeWindow(2));
        if ~isempty(time_indices)
            data(iData).data = data(iData).data(:, time_indices, :);
            data(iData).times = data(iData).times(time_indices);
            data(iData).pnts = length(time_indices);
        end
    end
end

% create the plot using EEGLAB's pop_comperp or simple plotting
if ~isempty(cluster) || isempty(channels)
    % single plot mode (like visual_comperp with electrodeCluster)
    fprintf('creating single plot\n');
    
    fig_handle = figure('Position', [100, 100, 800, 600]);
    hold on;
    
    colors = {[0 0.4470 0.7410], [0.8500 0.3250 0.0980], [0.9290 0.6940 0.1250], ...
              [0.4940 0.1840 0.5560], [0.4660 0.6740 0.1880]};
    line_styles = {'-', '--', '-.', ':', '-'};
    
    legend_entries = {};
    for i = 1:length(data)
        % get data to plot (use first channel since clustering averages everything)
        if size(data(i).data, 3) > 1
            % multiple trials: average across trials
            plot_data = mean(data(i).data(1, :, :), 3);
        else
            % single trial (grand average)
            plot_data = data(i).data(1, :);
        end
        
        % plot the trace
        plot(data(i).times, plot_data, ...
            'Color', colors{mod(i-1, length(colors))+1}, ...
            'LineStyle', line_styles{mod(i-1, length(line_styles))+1}, ...
            'LineWidth', 1.5);
        
        % create legend entry
        if ~isempty(data(i).setname)
            legend_entries{end+1} = data(i).setname;
        else
            legend_entries{end+1} = sprintf('condition_%d', i);
        end
    end
    
    % formatting
    xlabel('time (ms)');
    if gradientMode
        ylabel('gradient (μV/ms)');
    else
        ylabel('amplitude (μV)');
    end
    
    if ~isempty(plotTitle)
        title(plotTitle, 'Interpreter', 'none');
    end
    
    % reference lines
    xline(0, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    yline(0, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
    
    % legend & formatting
    legend(legend_entries, 'Location', 'best', 'Interpreter', 'none');
    set(gca, 'YDir', 'normal');
    grid on;
    box on;
    hold off;
    
else
    % multiple subplot mode (individual channels)
    fprintf('creating multiple channel plots\n');
    
    % use EEGLAB's pop_comperp function (like visual_comperp does)
    try
        pop_comperp(data, 1, 1:length(data), channels, 'addavg', 'off', 'addstd', 'off', ...
                   'addall', 'on', 'subavg', 'on', 'diffavg', 'on', 'diffstd', 'off', ...
                   'tplotopt', {'ydir', 1});
        fig_handle = gcf;
        
        if ~isempty(plotTitle)
            sgtitle(plotTitle, 'Interpreter', 'none');
        end
    catch
        % fallback: simple plotting if pop_comperp fails
        fprintf('pop_comperp failed, using simple plotting\n');
        fig_handle = figure();
        plot(data(1).times, data(1).data(1, :));
        xlabel('time (ms)');
        ylabel('amplitude (μV)');
        if ~isempty(plotTitle)
            title(plotTitle, 'Interpreter', 'none');
        end
    end
end

fprintf('ERP plot created successfully\n');

end