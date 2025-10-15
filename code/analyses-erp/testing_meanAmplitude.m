function [out, contrastResults, descriptiveResults, AnalysisData] = testing_meanAmplitude(inputPath,conditionFileNames, conditionLabels, outputFileName, rangeI, channel,varargin)
% testing_meanAmplitude() - Computes mean amplitudes of ERPs for statistical testing
%               and outputs data files for subsequent analysis in SPSS or R. Additionally,
%               statistical testing can be directily conducted for two conditions (paired
%               t-Test) and, if an optional ANOVA model is provided, also for up to
%               3-factorial within-subjects designs.
%
% Usage:
%   >> testing_meanAmplitude(folder, filenames, labels, outputFile, timeRange, electrode, optionalParameters)
%
%   Mandatory Inputs:
%           filenames   - ERP files to be used for statistical testing
%           folder      - Folder in which the files are located
%           labels      - Label for each condition (file) that is used for
%                         output file column headers, ANOVA table,...
%           outputFile  - Two output files are generated (one for SPSS, one
%                         for R) that include this string as part of their
%                         filename (along with the time range and electrode)
%           timeRange   - Time range for the mean amplitudes (e.g., [0 100])
%           electrode   - Electrode (e.g., {'FCz'}) that is used for
%                         calculating mean amplitudes. If more than one
%                         electrode is specified, the mean amplitude of this
%                         cluster is computed (e.g., {'FCz' 'Fz' 'FC1'}).
%
%   Optional Inputs:
%           'subjects'  - select a sub-range of the total subjects (that
%                         were included in the Grand Averaging).
%                         CAUTION: Specify subject numbers as they appear
%                         as trials in the Grand Average file (does not
%                         necessarily have to match the original subject
%                         numbers)!
%           'baseline'  - Lets you redefine the baseline period.
%           'minTrials' - Only subjects with at least X trials in the
%                         respective condition are included in the
%                         computation of the mean amplitudes.
%           'minTrialsCrit' - Use of 'minTrials' on 'subject' or
%                         'condition'. Default: 'subject'
%           'ranova'    - If you want to do statistical testing on more than
%                         two conditions, you need to specify a repeated
%                         measurements ANOVA model (ranova) in form of a
%                         table that specifies factor steps and factor
%                         names. (e.g., table({'Short';
%                         'Long';'Short';'Long'},{'Comp'; 'Comp'; 'Inc';
%                         'Inc';},'VariableNames',{'SOA' 'Compatibility') )
%           'tail'      - If using a t-test this gives the option to use
%                         'right', 'left' or 'both' to definde the direction
%                         of testing. 'both' is default.
%           'samples'   - If using a t-test this gives the option to use
%                         'between' or 'within' to definde relationship of
%                         samples. 'within' is default.
%
%
%   Example:
%   (2-factorial design with factors"ResponseType" (correct vs. error) and
%              "Congruency" (congruent vs. incongruent))
%   >> testing_meanAmplitude('ResponseLocked_', ...
%              {'grandAVG_corrCon'   'grandAVG_corrInc' 'grandAVG_errCon' 'grandAVG_errInc'}, ...
%              { 'corr_con'          'corr_inc'         'error_con'       'error_inc'}, ...
%              [300 500], {'Pz'}, 'P3-Results-2x2-ResponsetypeCongruency', ...
%       	   'subjects', [1:24], 'minTrials', 10, ...
%              'ranova', table({'corr';'corr';'err';'err'}, {'con';'inc';'con';'inc'}, 'VariableNames', {'ResponseType' 'Compatibility'}));
%
% (c) 2017 by Robert Steinhauser
%       modified:
%    Added: - Tail-Option: right left both
%           - Option for between Subject t-Testing

AnalysisData = [];
descriptiveResults = [];
subjects = [];
baseline = [];
anovaModel = [];
minTrials = 1;
minTrialsCrit = [];
gradientVar = [];
noPlot = 0;
tail = 'both';
tailInfo = 'two-tailed';
samples = 'within';
contrastResults = [];
outputDir = pwd;  % default to current directory

for i = 1:length(varargin)
    if strcmp(varargin{i}, 'outputDir')
        if length(varargin)>i
            outputDir = varargin{i+1};
        else
            disp('ERROR: Input for parameter ''outputDir'' is not valid!');
        end
    end
    if strcmp(varargin{i}, 'baseline')
        if length(varargin)>i
            baseline = varargin{i+1};
        else
            
            disp('ERROR: Input for parameter ''outprefix'' is not valid!');
        end
    end
    if strcmp(varargin{i}, 'subjects')
        if length(varargin)>i
            subjects = varargin{i+1};
        else
            disp('ERROR: Input for parameter ''subjects'' is not valid!');
        end
    end
    if strcmp(varargin{i}, 'minTrials')
        if length(varargin)>i
            minTrials = varargin{i+1};
        else
            disp('ERROR: Input for parameter ''minTrials'' is not valid!');
        end
    end
    if strcmp(varargin{i}, 'minTrialsCrit')
        if length(varargin)>i
            minTrialsCrit = varargin{i+1};
        else
            disp('ERROR: Input for parameter ''minTrialsCrit'' is not valid!');
        end
    end
    if strcmp(varargin{i}, 'ranova')
        if length(varargin)>i
            anovaModel = varargin{i+1};
        else
            disp('ERROR: Input for parameter ''anova'' is not valid!');
        end
    end
    if strcmp(varargin{i}, 'gradient')
        gradientVar = 1;
    end
    if strcmp(varargin{i}, 'noPlot')
        noPlot = 1;
    end
    if strcmp(varargin{i}, 'tail')
        if length(varargin)>i
            tail = varargin{i+1};
        else
            disp('ERROR: Input for parameter ''tail'' is not valid!');
        end
    end
    if strcmp(varargin{i}, 'samples')
        if length(varargin)>i
            samples = varargin{i+1};
        else
            disp('ERROR: Input for parameter ''tail'' is not valid!');
        end
    end
end

gmpath = inputPath;
lowTrialSubjects = [];
% lowTrialCondition = [];

for i = 1:length(conditionFileNames)
    data(i) = pop_loadset('filename', [conditionFileNames{i} '.set'], 'filepath', gmpath); %#ok<AGROW>
    signalRate = data(i).srate;
    rangeOffset = data(i).xmin*1000*-1;
    
    if ~isempty(subjects)
        data(i) = pop_select(data(i),'trial',subjects); %#ok<AGROW>
    end
    if ~isempty(baseline)
        data(i) = pop_rmbase(data(i),baseline); %#ok<AGROW>
    end
    lowTrialCondition.(conditionFileNames{i}) = zeros(1,size(data(i).data,3));
    
    for j = 1:size(data(i).data,3)
        
        tr = data(i).event(j).trials;
        
        if tr < minTrials && isempty(minTrialsCrit)
            lowTrialSubjects = unique([lowTrialSubjects j]);
        elseif tr < minTrials && ~isempty(minTrialsCrit)
            lowTrialSubjects = unique([lowTrialSubjects j]);
            if isempty(lowTrialSubjects)
                %              lowTrialCondition(i,j) = 0;
            else
                theseConditions = lowTrialCondition.(conditionFileNames{i});
                theseConditions(lowTrialSubjects) = 1;
                lowTrialCondition.(conditionFileNames{i}) = theseConditions;
                %               lowTrialCondition(i,[lowTrialSubjects]) = 1;
            end
            
        else
            if ~iscell(rangeI)
                range = (rangeI+rangeOffset).*signalRate/1000;
                currData = mean(data(i).data(channel,[floor(range(1)):floor(range(2))],j), 1); % orig: ei_channelNameToNumber(channel)
                if ~isempty(gradientVar)
                    currData =   gradient(currData);
                end
                v(i,j) = mean(currData);
                
            else  % If TimeWindow is a factor of the ANOVA
                for k = 1:length(rangeI)
                    
                    range = (rangeI{k}+rangeOffset).*signalRate/1000;
                    
                    currData = mean(data(i).data(channel,[floor(range(1)):floor(range(2))],j), 1); % orig: ei_channelNameToNumber(channel)
                    if ~isempty(gradientVar)
                        currData =   gradient(currData);
                    end
                    v(i+(k-1)*length(conditionFileNames),j) = mean(currData);
                    
                end
            end
        end
    end
    lowTrialSubjects = [];
end

if ~isempty(minTrialsCrit)
    % identify betweens
    Conditions = [];
    for o = 1:size(conditionFileNames,2)
        Conditions = [Conditions; lowTrialCondition.(conditionFileNames{o})]; %#ok<AGROW>
    end
        
    for i = 1:size(minTrialsCrit,2)
%         if sum(lowTrialCondition.(conditionFileNames{i}),2)~=0
            clear theseConditions
            clear toChangeCond
            toChangeNames = conditionFileNames(minTrialsCrit==minTrialsCrit(i));
            toChangeCond = minTrialsCrit==minTrialsCrit(i);
            Conditions(toChangeCond',any(Conditions(toChangeCond',:)== 1)) = 1;
            lowTrialCondition.(conditionFileNames{i}) = Conditions(i,:);  
%         end
    end
    
    uniqueConds = unique(minTrialsCrit);
    for i = 1:size(unique(minTrialsCrit),2)
        toChangeNames = conditionFileNames(minTrialsCrit==uniqueConds(i));
        for n = 1:size(toChangeNames,2)
            thisData.(['cond' num2str(i)]) = v(minTrialsCrit==uniqueConds(i),:);
            thisData.(['cond' num2str(i)])(:,lowTrialCondition.(toChangeNames{n})==1) = [];
        end
    end
    
    for i = 1:size(unique(minTrialsCrit),2)
        minValues = min(thisData.(['cond' num2str(i)]),[],1);
        thisData.(['cond' num2str(i)])(:,minValues==0)=[];
    end
    
    if length(conditionFileNames) == 2
        
        cond1 = thisData.cond1;
        cond2 = thisData.cond2;
        
        ei_disp(' ')
        ei_disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
        ei_disp('%  RESULTS OF PAIRED T-TEST  %');
        ei_disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
        ei_disp(' ')
        ei_disp(['   Folder: ' inputPath]);
        ei_disp(['   Time window: ' mat2str(rangeI)]);
        
        if isequal(samples, 'between')
            [~, P, ~, STATS] = ttest2(cond1,cond2,0.05,tail);
            out = {P STATS};
            ei_disp('   Between-Subjects');
        else
            [~, P, ~, STATS] = ttest(cond1,cond2,0.05,tail);
            out = {P STATS};
            ei_disp('   Within-Subjects');
        end
        
        if ~isempty(gradientVar)
            ei_disp('')
            ei_disp('==========================')
            ei_disp('=   GRADIENT ANALSYSIS   =')
            ei_disp('==========================')
            ei_disp('')
        end
        
        
        if ~isempty(baseline)
            ei_disp(['   Baseline: ' mat2str(baseline)]);
        end
        ei_disp('   ================================');
        ei_disp(['   ' conditionLabels{1} ':  M=' num2str(mean(cond1)) ' SD = ' num2str(std(cond1))]);
        ei_disp(['   ' conditionLabels{2} ':  M=' num2str(mean(cond2)) ' SD = ' num2str(std(cond2))]);
        ei_disp('   ================================');
        
        if isequal(tail, 'right')
            tailInfo = ['right-tailed: ' conditionLabels{1} ' > ' conditionLabels{2}];
        elseif isequal(tail, 'left')
            tailInfo = ['left-tailed: ' conditionLabels{1} ' < ' conditionLabels{2}];
        end
        
        ei_disp(['      t(' num2str(STATS.df) ') = ' num2str(STATS.tstat) ' , p = ' num2str(P) ' (' tailInfo ')']);
        ei_disp(' ');
        if size(cond1,2) ~= size(cond2,2)
            ei_disp(['      Unequal sample sizes: ' conditionLabels{1} ': ' num2str(size(cond1,2)) ' / '  conditionLabels{2} ': ' num2str(size(cond2,2))]);
        end
        ei_disp(['                   Hedge''s g (dependent) = Not jet available for unequal sizes of between subject ttests']);
        ei_disp(' ');
        
        
        dataOutput = [];
        for k = 1:2
            for p = 1:size(thisData.(['cond' num2str(k)])',2)
                Dummy = thisData.(['cond' num2str(k)])(p,:)';
                if length(Dummy) < max(structfun(@length,thisData))
                    Dummy(max(structfun(@length,thisData))) = 0;
                end
                dataOutput = [dataOutput Dummy]; %#ok<AGROW>
            end
        end
        AnalysisData = array2table(dataOutput, 'Variablenames', conditionLabels);

        
    elseif ~isempty(anovaModel) && size(anovaModel,2) == 2
        
        between_factors = [];
        UniqueColums = unique(anovaModel.(anovaModel.Properties.VariableNames{1}));
        for k = 1:size(UniqueColums,1)
            Index = min(find(contains(anovaModel.(anovaModel.Properties.VariableNames{1}),UniqueColums(k))));
            between_factors = [between_factors;  zeros(sum(lowTrialCondition.(conditionFileNames{Index})==0),1)+k];
        end
        
        dataArray = [];
        dataOutput = [];
        for k = 1:size(UniqueColums,1)
            dataArray = [dataArray; thisData.(['cond' num2str(k)])'];
            for p = 1:size(thisData.(['cond' num2str(k)])',2)
                Dummy = thisData.(['cond' num2str(k)])(p,:)';
                if length(Dummy) < max(structfun(@length,thisData))
                    Dummy(max(structfun(@length,thisData))) = 0;
                end
                dataOutput = [dataOutput Dummy]; %#ok<AGROW>
            end
        end
        
        out = simple_mixed_anova(dataArray, between_factors, anovaModel.Properties.VariableNames(2), anovaModel.Properties.VariableNames(1))
        
        AnalysisData = array2table(dataOutput, 'Variablenames', conditionLabels);
        
    end
    
    
    %% %%%
    
elseif isempty(minTrialsCrit)
    
    if ~isempty(minTrials)
        v(:,lowTrialSubjects) = [];
    end
    
    for iData=1:length(data)
        for iChannel = 1:size(data(iData).data,1)
            for iTrial = 1:size(data(iData).data,3)
                currData = data(iData).data(iChannel,:,iTrial);
                currData = gradient(currData);
                data(iData).data(iChannel,:,iTrial) = currData;
            end
        end
    end
    
    c = 0;
    minValues = min(abs(v),[],1);
    v(:,minValues==0)=[];
    out=cell(1,2);
    
    for i = 1:size(v,2)
        for j = 1:length(conditionFileNames)
            c=c+1;
            out{1}(c) = {[num2str(i)]};
            out{2}(c) = {conditionLabels{j}};
            out{3}(c) = {num2str(v(j,i))};
        end
    end
    
    if ~iscell(rangeI)
        if isnumeric(channel)
            channel_str = strrep(mat2str(channel), ' ', '_');
            ei_save([outputFileName '_(' mat2str(rangeI) '_' channel_str '_meanAmp)_R.txt'], out, 'w', 'comma');
        else
            ei_save([outputFileName '_(' mat2str(rangeI) '_' [channel{:}] '_meanAmp)_R.txt'], out, 'w', 'comma');
        end
    else % If TimeWindow is Factor
        if isnumeric(channel)
            channel_str = strrep(mat2str(channel), ' ', '_');
            ei_save([outputFileName '_(' strjoin(cellfun(@mat2str,rangeI,'UniformOutput',false)) '_' channel_str '_meanAmp)_R.txt'], out, 'w', 'comma');
        else
            ei_save([outputFileName '_(' strjoin(cellfun(@mat2str,rangeI,'UniformOutput',false)) '_' [channel{:}] '_meanAmp)_R.txt'], out, 'w', 'comma');
        end
    end
    
    out2=cell(1,2);
    out2{1}(1) = {'VP'};
    
    for j=1:length(conditionFileNames)
        out2{j+1}(1)={conditionLabels{j}};
    end
    
    c = 1;
    
    for i = 1:size(v,2)
        c=c+1;
        out2{1}(c) = {['VP' num2str(i)]};
        for j=1:length(conditionFileNames)
            out2{j+1}(c) = {num2str(v(j,i))};
        end
    end
    
    if ~iscell(rangeI)
        if isnumeric(channel)
            channel_str = strrep(mat2str(channel), ' ', '_');
            ei_save([outputFileName '_(' mat2str(rangeI) '_' channel_str '_meanAmp)_SPSS.txt'],out2, 'w', 'comma');
        else
            ei_save([outputFileName '_(' mat2str(rangeI) '_' [channel{:}] '_meanAmp)_SPSS.txt'],out2, 'w', 'comma');
        end
    else % If TimeWindow is Factor
        if isnumeric(channel)
            channel_str = strrep(mat2str(channel), ' ', '_');
            ei_save([outputFileName '_(' strjoin(cellfun(@mat2str,rangeI,'UniformOutput',false)) '_' channel_str '_meanAmp)_SPSS.txt'],out2, 'w', 'comma');
        else
            ei_save([outputFileName '_(' strjoin(cellfun(@mat2str,rangeI,'UniformOutput',false)) '_' [channel{:}] '_meanAmp)_SPSS.txt'],out2, 'w', 'comma');
        end
    end
    
    if length(conditionFileNames) == 2
        cond1 = squeeze(v(1,:));
        cond2 = squeeze(v(2,:));
        
        ei_disp(' ')
        ei_disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
        ei_disp('%  RESULTS OF PAIRED T-TEST  %');
        ei_disp('%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%');
        ei_disp(' ')
        ei_disp(['   Folder: ' inputPath]);
        ei_disp(['   Time window: ' mat2str(rangeI)]);
        
        if isequal(samples, 'between')
            ei_disp('');
            warning('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            warning('!   WARNING! Might have killed between subject trials due to zeros in just one subject!   !');
            warning('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            ei_disp('');
            [~, P, ~, STATS] = ttest2(cond1,cond2,0.05,tail);
            out = {P STATS};
            ei_disp('   Between-Subjects');
        else
            [~, P, ~, STATS] = ttest(cond1,cond2,0.05,tail);
            out = {P STATS};
            ei_disp('   Within-Subjects');
        end
        MESstats = mes(cond1',cond2','hedgesg','isDep',1);
        
        
        if ~isempty(gradientVar)
            ei_disp('')
            ei_disp('==========================')
            ei_disp('=   GRADIENT ANALSYSIS   =')
            ei_disp('==========================')
            ei_disp('')
        end
        
        
        if ~isempty(baseline)
            ei_disp(['   Baseline: ' mat2str(baseline)]);
        end
        ei_disp('   ================================');
        ei_disp(['   ' conditionLabels{1} ':  M=' num2str(mean(cond1)) ' SD = ' num2str(std(cond1))]);
        ei_disp(['   ' conditionLabels{2} ':  M=' num2str(mean(cond2)) ' SD = ' num2str(std(cond2))]);
        ei_disp('   ================================');
        
        if isequal(tail, 'right')
            tailInfo = ['right-tailed: ' conditionLabels{1} ' > ' conditionLabels{2}];
        elseif isequal(tail, 'left')
            tailInfo = ['left-tailed: ' conditionLabels{1} ' < ' conditionLabels{2}];
        end
        
        ei_disp(['      t(' num2str(STATS.df) ') = ' num2str(STATS.tstat) ' , p = ' num2str(P) ' (' tailInfo ')']);
        ei_disp(['                   Hedge''s g (dependent) = ' num2str(MESstats.hedgesg)]);
        ei_disp(' ');
        
        AnalysisData = table(cond1', cond2', 'Variablenames', {conditionLabels{1}, conditionLabels{2}});
        
        
    elseif ~isempty(anovaModel)
        
        t = array2table(v');
        conditionCount =  size(v,1);
        modelString = ['Var1-Var' num2str(conditionCount) ' ~ 1'];
        
        withinString = [];
        for i = 1 : length(anovaModel.Properties.VariableNames)
            withinString = [withinString anovaModel.Properties.VariableNames{i} '*'];
            
        end
        if iscell(rangeI)
            withinString = [withinString 'TimeWindow' '*'];
        end
        
        
        withinString(end) = [];
        
        disp(['ModelString: ' modelString]);
        disp(['WithinString: ' withinString]);
        
        
        if iscell(rangeI)
            stepsTime = length(rangeI);
            stepsOthers = length(conditionFileNames);
            newCol = table('Size',[stepsOthers*stepsTime 1],'VariableTypes',{'string'},'VariableNames',{'TimeWindow'});
            c = 1;
            for iT=1:stepsTime
                for iO = 1:stepsOthers
                    newCol(c,1) = {['Time' num2str(iT)]};
                    c = c + 1;
                end
            end
            
            anovaModel2 = repmat(anovaModel,stepsTime,1);
            anovaModel2 = [anovaModel2 newCol];
            anovaModel = anovaModel2;
            
        end
        
        
        rm = fitrm(t,modelString, 'WithinDesign', anovaModel)
        
        
        ranovatbl = ranova(rm,'WithinModel',withinString);
        
        if noPlot == 0
            [anovaResults, contrastResults, descriptiveResults] = ei_myRANOVA(v',anovaModel,'plot');
        else
            [anovaResults, contrastResults, descriptiveResults] = ei_myRANOVA(v',anovaModel);
        end
        
        AnalysisData = array2table(v', 'Variablenames', conditionLabels);
     
        
        if ~isempty(gradientVar)
            %          ei_disp(' ');
            ei_disp(' ');
            ei_disp('==========================')
            ei_disp('=   GRADIENT ANALSYSIS   =')
            ei_disp('==========================')
            ei_disp(' ')
        end
        
        anovaResults
        contrastResults
        descriptiveResults
        
        out = [];
        
        for i=1:height(anovaResults)
            out(i) = anovaResults{i,1} ;
        end
        
        disp(' ');
        
        if strcmp(samples,'between')
            ei_disp('');
            warning('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            warning('!   WARNING! You chose between samples but did not specify ''minTrialsCrit''! This is mandatory! Your output considers a within subject design!');
            warning('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
            ei_disp('');
        end        
        
        
        
        if length (anovaModel.Properties.VariableNames)==3
            posthoc_std = multcompare(rm,anovaModel.Properties.VariableNames{1},'By',anovaModel.Properties.VariableNames{2})
            posthoc_std = multcompare(rm,anovaModel.Properties.VariableNames{1},'By',anovaModel.Properties.VariableNames{3})
            posthoc_std = multcompare(rm,anovaModel.Properties.VariableNames{2},'By',anovaModel.Properties.VariableNames{3})
            
            posthoc_std = multcompare(rm,anovaModel.Properties.VariableNames{2},'By',anovaModel.Properties.VariableNames{1})
            posthoc_std = multcompare(rm,anovaModel.Properties.VariableNames{3},'By',anovaModel.Properties.VariableNames{1})
            posthoc_std = multcompare(rm,anovaModel.Properties.VariableNames{3},'By',anovaModel.Properties.VariableNames{2})
            
        end 
    end  
end