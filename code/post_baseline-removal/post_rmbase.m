% baseline_correction_and_reprocess.m
% Quick baseline correction and difference wave recalculation
% Author: Marlene Buch
% Date: 2025-10-16

%% Setup paths
sourceDir = 'C:\Users\localadmin\Documents\08_SocCEr\soccer-alpha\derivatives\2025-10-15_erp-postprocessing\grand_averages';
targetDir = 'C:\Users\localadmin\Documents\08_SocCEr\soccer-alpha\derivatives\2025-10-16_erp-postprocessing-baselined';

% Create target directories
grandAverDir = fullfile(targetDir, 'grand_averages');
diffWaveDir = fullfile(targetDir, 'difference_waves');
if ~exist(grandAverDir, 'dir'), mkdir(grandAverDir); end
if ~exist(diffWaveDir, 'dir'), mkdir(diffWaveDir); end

% Baseline parameters
baseline_window = [-150 -50]; % ms

%% List of grand average files to process
grandAvgFiles = {
    % Visible conditions
    'grandAVG_111_social_vis_corr'
    'grandAVG_211_nonsoc_vis_corr'
    'grandAVG_112_social_vis_FE'
    'grandAVG_212_nonsoc_vis_FE'
    'grandAVG_113_social_vis_NFE'
    'grandAVG_213_nonsoc_vis_NFE'
    'grandAVG_110_social_vis_error'     % collapsed error (112+113)
    'grandAVG_210_nonsoc_vis_error'     % collapsed error (212+213)
    % Invisible conditions
    'grandAVG_102_social_invis_FE'
    'grandAVG_202_nonsoc_invis_FE'
    'grandAVG_104_social_invis_NFG'
    'grandAVG_204_nonsoc_invis_NFG'
};

%% Process grand averages - baseline correction
fprintf('Starting baseline correction...\n');
fprintf('Baseline window: [%d %d] ms\n\n', baseline_window(1), baseline_window(2));

% Store loaded EEG structures for difference wave calculation
EEG_data = struct();

for i = 1:length(grandAvgFiles)
    filename = grandAvgFiles{i};
    fprintf('Processing %d/%d: %s... ', i, length(grandAvgFiles), filename);
    
    % Load grand average
    EEG = pop_loadset('filename', [filename '.set'], 'filepath', sourceDir);
    
    % Apply baseline correction
    EEG = pop_rmbase(EEG, baseline_window);
    
    % Store in structure for later use
    EEG_data.(filename) = EEG;
    
    % Save baseline-corrected file
    pop_saveset(EEG, 'filename', [filename '.set'], 'filepath', grandAverDir);
    
    fprintf('Done!\n');
end

fprintf('\n✓ All grand averages baseline-corrected and saved to:\n  %s\n\n', grandAverDir);

('\n✓ Collapsed error conditions created and saved\n\n');

%% Load condition_inclusion mapping from original processing
fprintf('Loading subject-condition mapping from original processing...\n');
originalGrandAvgFile = fullfile(sourceDir, 'grand_averages.mat');
if ~exist(originalGrandAvgFile, 'file')
    error('Cannot find original grand_averages.mat file needed for subject matching!');
end
load(originalGrandAvgFile, 'condition_inclusion', 'included_subjects', 'codes');
fprintf('Loaded mapping for %d subjects\n\n', length(included_subjects));

%% Calculate difference waves with proper subject matching
fprintf('Calculating difference waves with subject matching...\n\n');

% Define difference wave pairs (error/response minus correct)
diffWavePairs = {
    % Visible-target difference waves
    {'diffWave_soc_vis_FE',     'grandAVG_112_social_vis_FE',    'grandAVG_111_social_vis_corr'}
    {'diffWave_nonsoc_vis_FE',  'grandAVG_212_nonsoc_vis_FE',    'grandAVG_211_nonsoc_vis_corr'}
    {'diffWave_soc_vis_NFE',    'grandAVG_113_social_vis_NFE',   'grandAVG_111_social_vis_corr'}
    {'diffWave_nonsoc_vis_NFE', 'grandAVG_213_nonsoc_vis_NFE',   'grandAVG_211_nonsoc_vis_corr'}
    {'diffWave_soc_vis_error',  'grandAVG_110_social_vis_error',  'grandAVG_111_social_vis_corr'}
    {'diffWave_nonsoc_vis_error', 'grandAVG_210_nonsoc_vis_error', 'grandAVG_211_nonsoc_vis_corr'}
    % Invisible-target difference waves
    {'diffWave_soc_invis_FE',    'grandAVG_102_social_invis_FE',  'grandAVG_111_social_vis_corr'}
    {'diffWave_nonsoc_invis_FE', 'grandAVG_202_nonsoc_invis_FE',  'grandAVG_211_nonsoc_vis_corr'}
    {'diffWave_soc_invis_NFG',   'grandAVG_104_social_invis_NFG', 'grandAVG_111_social_vis_corr'}
    {'diffWave_nonsoc_invis_NFG', 'grandAVG_204_nonsoc_invis_NFG', 'grandAVG_211_nonsoc_vis_corr'}
};

% Map code names to code numbers
codeMap = containers.Map(...
    {'111', '112', '113', '110', '211', '212', '213', '210', '102', '104', '202', '204'}, ...
    {111, 112, 113, 110, 211, 212, 213, 210, 102, 104, 202, 204});

for i = 1:length(diffWavePairs)
    diffName = diffWavePairs{i}{1};
    errorFile = diffWavePairs{i}{2};
    correctFile = diffWavePairs{i}{3};
    
    fprintf('Creating %d/%d: %s\n', i, length(diffWavePairs), diffName);
    fprintf('  = %s - %s\n', errorFile, correctFile);
    
    % Extract code numbers from file names
    errorCode = str2double(regexp(errorFile, '\d{3}', 'match', 'once'));
    correctCode = str2double(regexp(correctFile, '\d{3}', 'match', 'once'));
    
    % Find code indices
    errorCodeIdx = find(codes == errorCode);
    correctCodeIdx = find(codes == correctCode);
    
    if isempty(errorCodeIdx) || isempty(correctCodeIdx)
        fprintf('  WARNING: Cannot find code mapping for %s\n', diffName);
        continue;
    end
    
    % Find subjects that have BOTH conditions
    subjects_for_this_diffwave = {};
    error_subject_indices = [];
    correct_subject_indices = [];
    
    for subj_idx = 1:length(included_subjects)
        subject = included_subjects{subj_idx};
        subject_inclusion = condition_inclusion(subject);
        
        % Check if subject has both conditions
        if subject_inclusion(errorCodeIdx) && subject_inclusion(correctCodeIdx)
            subjects_for_this_diffwave{end+1} = subject;
            
            % Count position in each condition's data
            % For error condition
            error_pos = 0;
            for j = 1:subj_idx
                temp = condition_inclusion(included_subjects{j});
                if temp(errorCodeIdx)
                    error_pos = error_pos + 1;
                end
            end
            error_subject_indices = [error_subject_indices, error_pos];
            
            % For correct condition
            correct_pos = 0;
            for j = 1:subj_idx
                temp = condition_inclusion(included_subjects{j});
                if temp(correctCodeIdx)
                    correct_pos = correct_pos + 1;
                end
            end
            correct_subject_indices = [correct_subject_indices, correct_pos];
        end
    end
    
    % Create difference wave if we have matched subjects
    if ~isempty(error_subject_indices)
        % Get the baseline-corrected EEG structures
        EEG_error = EEG_data.(errorFile);
        EEG_correct = EEG_data.(correctFile);
        
        % Extract only matched subjects' data
        error_data = EEG_error.data(:, :, error_subject_indices);
        correct_data = EEG_correct.data(:, :, correct_subject_indices);
        
        % Create difference wave
        EEG_diff = EEG_error;  % Use as template
        EEG_diff.data = error_data - correct_data;
        EEG_diff.trials = length(subjects_for_this_diffwave);
        EEG_diff.setname = diffName;
        
        % Save difference wave
        pop_saveset(EEG_diff, 'filename', [diffName '.set'], 'filepath', diffWaveDir);
        fprintf('  Created successfully with %d matched subjects\n\n', length(subjects_for_this_diffwave));
    else
        fprintf('  WARNING: No subjects have both conditions - skipping\n\n');
    end
end

fprintf('\n✓ All difference waves calculated and saved to:\n  %s\n\n', diffWaveDir);

%% Summary
fprintf('========================================\n');
fprintf('BASELINE CORRECTION COMPLETE!\n');
fprintf('========================================\n');
fprintf('Processed %d grand averages\n', length(grandAvgFiles));
fprintf('Created %d difference waves\n', length(diffWavePairs));
fprintf('\nOutput location:\n%s\n', targetDir);
fprintf('  /grand_averages/    - Baseline-corrected grand averages\n');
fprintf('  /difference_waves/  - Recalculated difference waves\n');
fprintf('========================================\n');