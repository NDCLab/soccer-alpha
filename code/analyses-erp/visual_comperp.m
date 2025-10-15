function visual_comperpMOD(filenames, folder,  varargin)
% visual_comperp() - Plots ERP waves for comparison.
%
% Usage: 
%   >> visual_comperp(filenames, folder, optionalParameters)
% 
%   Mandatory Inputs:
%           filenames   - Files to be plotted as ERP waves
%           folder      - Folder in which the files are located
%
%   Optional Inputs:
%           'subjects'  - select a sub-range of the total subjects (that
%                         were included in the Grand Averaging). 
%                         CAUTION: Specify subject numbers as they appear
%                         as trials in the Grand Average file (does not
%                         necessarily have to match the original subject
%                         numbers)!
%           'channels'  - Electrodes that are to be plotted
%           'baseline'  - Lets you redefine the baseline period.
%                         'baselineAbsolute' - Substracts a baseline period 
%                         while keeping the original interindividual variance 
%                         (unconventional)
%           'lowpass'   - Applies an (additional) lowpass filter of X Hz to
%                         the ERPs (for display only, filtering is not saved)
%           'notch'     - Applies an (additional) notch filter to display only
%                         one specific frequency (of X Hz) to the ERPs (for 
%                         display only, filtering is not saved)
%           'electrodeCluster' - Displays the mean ERP amplitudes of a
%                         specified subset of electrodes
%           'minTrials' - Subject included only if minimum number of trials 
%                         in all conditions at lest X. Default: 1
%           'minTrialsCrit' - Use of 'minTrials' on 'subject' or
%                         'condition'. Default: 'subject'
%           'subjectWise' - Displays subject-wise ERPs from one electrode
%                         (which has to be specified as a parameter), together
%                         with the variance and trial number per subject.
%           'gradient'  - instead of the actual ERPs, this displays the
%                         gradient (slope) at each timepoint.
%           'clusterPermutationTest' - Additionally runs a cluster-based
%                         permutation test (Massive Univariate Toolbox) on
%                         the data (only 2 conditions allowed!). You have
%                         to specify the following parameters:
%                         > Electrode (currently allows only 1 electrode, e.g. 'FCz')
%                         > Time Window (e.g., [-500 1000])
%                         > Number of Permutations (e.g., 10000)
%                         > Cluster inclusion threshold (e.g., .01)
%                         > FWE-rate (e.g., .05)
%
%   Example: 
%   >> visual_comperp({'grandAVG_correct' 'grandAVG_error'}, 'ResponseLocked_', ...
%              'subjects', [1:10 12:24], 'channels', [1:64], 'lowpass', 15,...
%              'electrodeCluster', {'PO7' 'PO8'});
%                                         
% (c) 2017 by Robert Steinhauser
%  modified by Peter Löschner 23.02.22:
%    Added: - mintrial option to just use ocndition and not participant
%           



inprefix = '';
outprefix = '';
subjects = [];
baseline = [];
baselineAbsolute = [];
lowpass = [];
notch = [];
channels = [];
minTrials = 1;
minTrialsCrit = [];
synch = [];
cluster = [];
gradientVar = [];
CI = [];
subjectWise = [];
clustPermTestTimeWindow = [];
clustPermTestPermutations = [];
clustPermTestInclusionThresh = [];
clustPermTestFWE = [];
clustPermTestElectrode = [];

for i = 1:length(varargin)
    if strcmp(varargin{i}, 'subjects') 
       if length(varargin)>i  
           subjects = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''subjects'' is not valid!');
       end
    end    
    if strcmp(varargin{i}, 'baseline') 
       if length(varargin)>i  
           baseline = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''baseline'' is not valid!');
       end
    end  
    if strcmp(varargin{i}, 'lowpass') 
       if length(varargin)>i  
           lowpass = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''lowpass'' is not valid!');
       end
    end      
    if strcmp(varargin{i}, 'notch') 
       if length(varargin)>i  
           notch = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''notch'' is not valid!');
       end
    end      
    if strcmp(varargin{i}, 'channels') 
       if length(varargin)>i  
           channels = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''channels'' is not valid!');
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
    if strcmp(varargin{i}, 'synch') 
           synch = 1; 
    end  
    if strcmp(varargin{i}, 'CI') 
       if length(varargin)>i  
           CI = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''CI'' is not valid!');
       end
    end 
    if strcmp(varargin{i}, 'subjectWise') 
       if length(varargin)>i  
           subjectWise = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''subjectWise'' is not valid!');
       end
    end   
    if strcmp(varargin{i}, 'clusterPermutationTest') 
       if length(varargin)>i+4  
           clustPermTestElectrode = varargin{i+1}; 
           clustPermTestTimeWindow = varargin{i+2}; 
           clustPermTestPermutations = varargin{i+3};
           clustPermTestInclusionThresh = varargin{i+4};
           clustPermTestFWE = varargin{i+5};
          
       else
           disp('ERROR: Inputs for parameter ''clusterPermutationTest'' are not valid!');
       end
    end      
    
    if strcmp(varargin{i}, 'baselineAbsolute') 
       if length(varargin)>i  
           baselineAbsolute = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''baselineAbsolute'' is not valid!');
       end
    end   
    if strcmp(varargin{i}, 'gradient')  
           gradientVar = 1; 
    end     
    
    if strcmp(varargin{i},'electrodeCluster')
        if length(varargin)>i  
           cluster = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''electrodeCluster'' is not valid!');
       end
       
        
    end
end



% lowTrialCondition = [];
lowTrialSubjects = [];
    
for i = 1 : length(filenames)     
    
    fn = [ filenames{i} '.set'];   
    if exist([folder '\' fn], 'file') ~= 2
         fn = ['grandAVG_' strrep(fn,'grandAVG_','')];
    end
    
    data(i) = pop_loadset('filename', fn,'filepath',folder);
    if ~isempty(subjects)
        
        if length(subjects) <= size(data(i).data,3)        
            data(i) = pop_select(data(i),'trial',subjects);
        else
            warning('ACHTUNG: TRIAL RANGE WAR KLEINER!');
        end
        
    end
    if ~isempty(channels)
        data(i) = pop_select(data(i),'channel',channels);
    end          
    if ~isempty(baseline)
        data(i) = pop_rmbase(data(i),baseline);
    end    
    if ~isempty(lowpass)
         sz = size(data(i).data);
        data(i) = pop_eegfilt(data(i),0,lowpass,[],0,0,0,'fir1',0);
       % EEG, locutoff, hicutoff, filtorder, revfilt, usefft, plotfreqz, firtype,
        data(i).data = reshape(data(i).data,sz);
    end      
    if ~isempty(notch)
        data(i) = pop_eegfilt(data(i),notch-1,notch+1,[],1);
    end   
    
     lowTrialCondition.(filenames{i}) = zeros(1,size(data(i).data,3));
%     lowTrialCondition(i,:) = zeros(1,size(data(i).data,3));
    
    if ~isempty(minTrials)
        e = data(i).event;
        trials = [e(:).trials];    
        trials(trials<minTrials) = -1;

        lowTrialSubjects = unique([lowTrialSubjects find(trials == -1)]);    
        
        if ~isempty(minTrialsCrit)
            if isempty(lowTrialSubjects)
%                  lowTrialCondition.(filenames{i}) = 0;
%                 lowTrialCondition(i,:) = 0;
            else
                theseConditions = lowTrialCondition.(filenames{i});
                theseConditions(lowTrialSubjects) = 1;
                lowTrialCondition.(filenames{i}) = theseConditions;
%                 lowTrialCondition(i,[lowTrialSubjects]) = 1;
            end
            lowTrialSubjects = [];
        end
    end        
     
    s = filenames{i};
    s = strrep(s,'grandAVG_','');
    s = strrep(s,'_',' ');
    data(i).setname = s;
       
end

if ~isempty(minTrialsCrit)
    uniqueConds = unique(minTrialsCrit);
    for i = 1:size(unique(minTrialsCrit),2)
        theseConditions = [];
        toChangeNames = filenames(minTrialsCrit==uniqueConds(i));
        for n = 1:size(toChangeNames,2)
            theseConditions(n,:) = lowTrialCondition.(toChangeNames{n});
        end
        for n = 1:size(toChangeNames,2)
            lowTrialCondition.(toChangeNames{n}) = [sum(theseConditions,1) ~= 0];
        end
    end
end
    
% for i = 1:size(minTrialsCrit,2)
%     if sum(lowTrialCondition.(filenames{i}),2)~=0
%         toChangeNames = filenames(minTrialsCrit==minTrialsCrit(i));
%         for n = 1:size(toChangeNames,2)
%             theseConditions(n,:) = lowTrialCondition.(toChangeNames{n});
% 
%         end
% %         lowTrialCondition(minTrialsCrit==minTrialsCrit(i),lowTrialCondition.(filenames{i})==1) = 1;
%     end
% end


% for i = 1:size(minTrialsCrit,2)
%     if sum(lowTrialCondition(i,:),2)~=0
%         lowTrialCondition(minTrialsCrit==minTrialsCrit(i),lowTrialCondition(i,:)==1) = 1;
%     end
% end


% 
% % % if ~isempty(transform)
% % zData = zeros([64 768 1]);
% DummyMean = zeros([64 768 length(filenames)]);
% DummySD = zeros([64 768 length(filenames)]);
% data2 = data;
% 
% for i = 1:length(filenames)
%     for x = 1:size(data(i).data,1)
%         for y = 1:size(data(i).data,2)
%             DummyMean(x, y, i) = mean(data(i).data(x,y,:));
%             DummySD(x, y, i) = std(data(i).data(x,y,:));
%         end
%     end
% end
% MeanAll = mean(DummyMean(:,:,:),3);
% for i = 1:length(filenames)
%     data2(i).data = zeros([64 768 1]);
%     for x = 1:size(data(i).data,1)
%         for y = 1:size(data(i).data,2)
%             data2(i).data(x,y,1) = (DummyMean(x,y,i) - MeanAll(x,y,:)) / std(DummyMean(x,y,:));
%         end
%     end
% end



% % end

if ~isempty(minTrials)
   for i=1:length(data)
       
       if isempty(minTrialsCrit)
           data(i) = pop_select(data(i),'notrial',lowTrialSubjects);
       elseif  ~isempty(minTrialsCrit)
               data(i) = pop_select(data(i),'notrial',find(lowTrialCondition.(filenames{i})==1));          
       end 
       
       subj = [];
       for ii = 1:length(data(i).event)
          s = [data(i).event(ii).setname] ;
          s2 = s(strfind(s,'VP')+2:strfind(s,' epochs'));
          try
          subj = [subj str2num(s2)];
          catch
          subj = [subj ' xx '];    
          end
       end
       disp(['Subjects with too less trials: ' mat2str(subj)]);
       
   end    
end

if ~isempty(gradientVar)
    for iData=1:length(data)
        for iChannel = 1:size(data(iData).data,1)
            for iTrial = 1:size(data(iData).data,3)
                currData = data(iData).data(iChannel,:,iTrial);
                currData = gradient(currData);
                data(iData).data(iChannel,:,iTrial) = currData;
                
            end
        end     
    end
end
    

if ~isempty(baselineAbsolute)
    srate = data(1).srate;
    for iData = 1:length(data)
        for iElectrode = 1:size(data(iData).data,1)
            baselineStartFrame = ei_TimeToFrame(baselineAbsolute(1),srate,data(1).xmin*-1000);
            baselineEndFrame = ei_TimeToFrame(baselineAbsolute(2),srate,data(1).xmin*-1000);
            baselineData = data(iData).data(iElectrode,baselineStartFrame:baselineEndFrame,:);
            baselineData = squeeze(mean(baselineData,3));
            offset = mean(baselineData);
            
            for iTrial = 1:size(data(iData).data,3)
                data(iData).data(iElectrode,:,iTrial) = ...
                    data(iData).data(iElectrode,:,iTrial)-offset;
            end
        end
    end
end


if ~isempty(synch)
    
    if size(data(1).data,3) ~= size(data(2).data,3)
        e1 = data(1).event;
        setnames1 = {e1(:).setname};
        for i = 1 : length(setnames1)
            set1(i) =  str2num(setnames1{i}(findstr(' (',setnames1{i})+4:end-1));
        end
        e2 = data(2).event;
        setnames2 = {e2(:).setname};
        for i = 1 : length(setnames2)
            set2(i) =  str2num(setnames2{i}(findstr(' (',setnames2{i})+4:end-1));
        end
        
        if size(data(1).data,3) > size(data(2).data,3)
            l = size(data(1).data,3);
            l2 = size(data(2).data,3);
            s1 = set1;
            s2 = set2;
        else
            l = size(data(2).data,3);
            l2 = size(data(1).data,3);
            s1 = set2;
            s2 = set1;
        end
        
        delete = [];
        delete2 = [];
        for i = 1:l
            if ~ismember(s1(i),s2)
                delete = [delete i];
            end
        end
        for i = 1:l2
            if ~ismember(s2(i),s1)
                delete2 = [delete2 i];
            end
        end
        
        
        data(1) = pop_select(data(1),'notrial',delete);
        data(2) = pop_select(data(2),'notrial',delete2);
        disp('');
        
    end
end


if ~isempty(cluster)
   for iC = 1:length(data)
       if isnumeric(cluster)
           channels = cluster;  % already numeric, use directly
       else
           channels = ei_channelNameToNumber(cluster);  % convert names to numbers
       end
   dataCluster = mean(data(iC).data(channels,:,:),1);
   data(iC).data = repmat(dataCluster,size(data(iC).data,1),1,1);
   for i = 1:size(data(iC).chanlocs,2)
       if isnumeric(cluster)
           data(iC).chanlocs(i).labels = mat2str(cluster);  % convert numbers to string
       else
           data(iC).chanlocs(i).labels = cell2mat(cluster);  % original for cell arrays
       end
   end
   
   end
    
end


if ~isempty(clustPermTestTimeWindow)
   if length(data) ~= 2
      error('Cluster-Perutation-Tests derzeit nur mit 2 Bedingungen möglich!'); 
   end
   
   
   
   
   srate = data(1).srate;
   
   if strcmp(clustPermTestElectrode,'ALL')
       electrode = 1:64;
       electrodeNames = ei_channelNumberToName(1:64);
   else
        electrode = ei_channelNameToNumber(clustPermTestElectrode);
        electrodeNames = ei_channelNumberToName(electrode);
   end
   
 

   
   timeArea = [ei_TimeToFrame(clustPermTestTimeWindow(1),srate,data(1).xmin*-1000) : ei_TimeToFrame(clustPermTestTimeWindow(2),srate,data(1).xmin*-1000)];
   
   
    cond1 = data(1).data(electrode,timeArea,:);
    cond2 = data(2).data(electrode,timeArea,:);
    
     condBoth = cond2-cond1; 

    
    chan_hood = spatial_neighbors(data(1).chanlocs,50); % 0.61  % 50
   
  [pval, t_orig, clust_info, seed_state, est_alpha] = clust_perm1(condBoth,chan_hood    ,clustPermTestPermutations,clustPermTestFWE,  0,   clustPermTestInclusionThresh,     2,[]);
                                                  
   
%    
%    alphaup = 1-0.05/2;
%    alphalow = 0.05/2;
%    upp = tinv(alphaup,ttstats.df);
%    low = tinv(alphalow,ttstats.df);
%    thresh = upp;
%    chan_hood = 1;
%    [clust_membership_pos, n_clust_pos]=find_clusters(tValues,upp,chan_hood,1);
%    [clust_membership_neg, n_clust_neg]=find_clusters(tValues,low,chan_hood,-1);
%     
   
   
%    
%    for iFrame = 1 : size(data(1).data,2)
%       cond1 = data(1).data(electrode,iFrame,:);
%       cond2 = data(2).data(electrode,iFrame,:);
%        
%       [tth ttp ttci ttstats] = ttest2(cond1,cond2);
%       tValues(iFrame) = ttstats.tstat;
%    end
%        
%    alphaup = 1-0.05/2;
%    alphalow = 0.05/2;
%    upp = tinv(alphaup,ttstats.df);
%    low = tinv(alphalow,ttstats.df);
%    thresh = upp;
%    chan_hood = 1;
%    [clust_membership_pos, n_clust_pos]=find_clusters(tValues,upp,chan_hood,1);
%    [clust_membership_neg, n_clust_neg]=find_clusters(tValues,low,chan_hood,-1);
%     
end


if ~isempty(CI)
    srate = data(1).srate;
    x = data(1).times;%[-500:1000/srate:1000];
    con = filenames;
    for i = 1:length(filenames) % cons
        
        ds = data(i);
        d(i,:,:) = squeeze(mean(ds.data(ei_channelNameToNumber(CI),:,:),1)); % (con, sample point, subject)
        
    end


    % confidence interval (independently for each sample point)
    for j = 1:size(d,2) % sample points
        dall = mean(mean(d(:,j,:)));
        for i = 1:length(con) % cons
            for k = 1:size(d,3) % subjects
                meand(i,:) = mean(d(i,:,:),3);
                dk = mean(d(:,j,k));
                normd(i,j,k) = d(i,j,k) - dk + dall;
            end
            ci(i,j) = 1.96 * std(normd(i,j,:))/sqrt(size(d,3));
        end
    end
    
    % confidence interval for the difference
    diff = squeeze(d(2,:,:) - d(1,:,:));
    meandiff = mean(diff,2);
    for i = 1:size(diff,1)
        diffci(i) = 1.96 * std(diff(i,:)) / sqrt(size(diff,2));
    end


%  yt = [1:.1:1.9]; xt = [-500:100:500]; xl = [-500 500]; locval = 'southwest'; % Target
% yt = [.7:.1:1.8]; xt = [-500:100:500]; xl = [-500 500]; locval = 'northeast'; % Distractor
% yt = [-.1:.1:.6]; xt = [-500:100:500]; xl = [-500 500]; locval = 'northeast'; % Selectivity


     
    
    
%     if ~isempty(baselineAbsolute)
%         
%         for i= 1:size(meand,1)
%             baselineStartFrame = ei_TimeToFrame(baselineAbsolute(1),srate,data(1).xmin*-1000);
%             baselineEndFrame = ei_TimeToFrame(baselineAbsolute(2),srate,data(1).xmin*-1000);
%             baselineData = meand(i,baselineStartFrame:baselineEndFrame);
%             offset = mean(baselineData);
%             
%             meand(i,:) = meand(i,:)-offset;
%         end
%        
%        
%         
%     end
    
    yMin = min(min(meand-ci,[],2));
    yMax = max(max(meand+ci,[],2));
    xMin = data(1).xmin*1000;
    xMax = data(1).xmax*1000;  

    figure;
    hold on;
    bh = shadedErrorBar(x,meand(1,:),ci(1,:),'b',1);
    rh = shadedErrorBar(x,meand(2,:),ci(2,:),'r',1);  
   % hold off;
    set(gcf,'Color',[1 1 1]);
    set(gca,'Box','Off');
    set(gca, 'XLim',[xMin xMax], 'YLim',[yMin yMax]);   
%      set(gca, 'XTick',xt, 'YTick',yt);
    set(gca, 'FontName','Arial', 'FontSize',18);
    lh = line([-1000 1000],[0 0]);
    set(lh, 'Color',[0 0 0],'LineStyle','--');
    lh2 = line([0 0],[-1000 1000]);
    set(lh2, 'Color',[0 0 0],'LineStyle','--');
    xlabel('Time (ms)','FontName','Arial','FontWeight','bold','FontSize',18);
    ylabel('Normalized Amplitude','FontName','Arial','FontWeight','bold','FontSize',18,'Rotation',90);
    l = legend([bh.mainLine rh.mainLine],'Correct','Error');
%     set(l,'FontName','Arial','FontSize',18,'location',locval);
    legend('boxoff');
    
    
    if ~isempty(clustPermTestTimeWindow)
        
        offset = ei_TimeToFrame(clustPermTestTimeWindow(1),srate,data(1).xmin*-1000);
         
        disp(['NEGATIVE CLUSTERS:']);
        negClusterIds = clust_info.neg_clust_ids;
        for i=1:length(clust_info.neg_clust_pval) 
            clusterInd = find(negClusterIds==i);
            [clusterCoordElec,clusterCoordTime] = ind2sub(size(negClusterIds),clusterInd);

           clusterStart = ei_FrameToTime(clusterCoordTime(1)+offset,srate,data(1).xmin*-1000);
           clusterEnd = ei_FrameToTime(clusterCoordTime(end)+offset,srate,data(1).xmin*-1000);
           
           if clust_info.neg_clust_pval(i) <= clustPermTestFWE
               lh = line([clusterStart clusterEnd],[yMin+(yMax-yMin)*0.1 yMin+(yMax-yMin)*0.1]);
               xval = clusterStart;
               yval = yMin+(yMax-yMin)*0.05;
               text(xval,double(yval),['p=' num2str(clust_info.neg_clust_pval(i))]);
               set(lh, 'Color',[0 0 1],'LineWidth',3);
           end
           
           
           disp(['Cluster ' num2str(i) ': ' num2str(round2(clusterStart,0)) 'ms to ' num2str(round2(clusterEnd,0))  'ms,  p = ' num2str(clust_info.neg_clust_pval(i)) '     Electrodes: ' strjoin(electrodeNames(unique(clusterCoordElec)),', ')]);
           
        end
        disp(['POSITIVE CLUSTERS:']);
        posClusterIds = clust_info.pos_clust_ids;
         for i=1:length(clust_info.pos_clust_pval)  
            clusterInd = find(posClusterIds==i);
            
            [clusterCoordElec,clusterCoordTime] = ind2sub(size(posClusterIds),clusterInd);

           clusterStart = ei_FrameToTime(clusterCoordTime(1)+offset,srate,data(1).xmin*-1000);
           clusterEnd = ei_FrameToTime(clusterCoordTime(end)+offset,srate,data(1).xmin*-1000);
            
          if clust_info.pos_clust_pval(i) <= clustPermTestFWE 
           lh = line([clusterStart clusterEnd],[yMin+(yMax-yMin)*0.1 yMin+(yMax-yMin)*0.1]);
           set(lh, 'Color',[1 0 0],'LineWidth',3);        
           xval = clusterStart;
           yval = yMin+(yMax-yMin)*0.05;
         
           text(xval,double(yval),['p=' num2str(clust_info.pos_clust_pval(i))]);
           
          end  
           disp(['Cluster ' num2str(i) ': ' num2str(round2(clusterStart,0)) 'ms to ' num2str(round2(clusterEnd,0))  'ms,  p = ' num2str(clust_info.pos_clust_pval(i)) '     Electrodes: ' strjoin(electrodeNames(unique(clusterCoordElec)),', ')]);
           
        end       
      
    end
    
    



elseif ~isempty(subjectWise)
    
    figure;
    subplot(4,1,[1 2]);
    hold on;
    colors = {'b' 'r' 'g' 'k'};
    xachse = data(i).times;
    xlim([data(i).times(1) data(i).times(end)]);
    line([data(i).times(1) data(i).times(end)], [0 0],'color','k');
    line([0 0], [-100 100],'color','k');
    minY = 0;
    maxY = 0;
    c = 1;
    for i=1:length(data)
        for j=1:size(data(i).data,3)
            currData = data(i).data(ei_channelNameToNumber(subjectWise),:,j);
            
            if max(currData) > maxY, maxY = max(currData); end
            if min(currData) < minY, minY = min(currData); end
                
            
            plot(xachse,currData,colors{i});
            
            disp([data(i).event(j).setname ': SD = ' num2str(round2(std(currData),2))   ' (' num2str(data(i).event(j).trials) ' trials)']);
            SDs(c) = std(currData)^2;
            
            SDticks{c} = [num2str(j)];
            trials(c) = data(i).event(j).trials;
            c = c + 1;
        end       
          
        
        
    end
    ylim([minY*1.1 maxY*1.1]);
    
    
    subplot(4,1,3);
    
    bar(SDs);
    set(gca,'XTick',1:length(SDs));
    set(gca,'XTickLabel',SDticks);
    
     
    subplot(4,1,4);
    
    bar(trials);
    set(gca,'XTick',1:length(SDs));
    set(gca,'XTickLabel',SDticks);
       
    

    
else



pop_comperp( data, 1, [1:length(data)] ,[],'addavg','off','addstd','off','addall','on','subavg','on','diffavg','on','diffstd','off','tplotopt',{'ydir' 1});
% pop_comperp( data2, 1, [1:length(data2)] ,[],'addavg','off','addstd','off','addall','on','subavg','off','diffavg','on','diffstd','off','tplotopt',{'ydir' 1});

% newdata = data;
% newdata(:,4) = newdata(:,1);
% newdata(4).setname = 'add';
% A = data(1).data;
% B = data(2).data;
% C = A+B;
% newdata(4).data = C;
% 
% pop_comperp( newdata, 1, [1:length(newdata)] ,[],'addavg','off','addstd','off','addall','on','subavg','on','diffavg','on','diffstd','off','tplotopt',{'ydir' 1});


if ~isempty(clustPermTestTimeWindow)
    
    offset = ei_TimeToFrame(clustPermTestTimeWindow(1),srate,data(1).xmin*-1000);
    
    disp(['NEGATIVE CLUSTERS:']);
    negClusterIds = clust_info.neg_clust_ids;
    for i=1:length(clust_info.neg_clust_pval)
        clusterInd = find(negClusterIds==i);
        clusterStart = ei_FrameToTime(clusterInd(1)+offset,srate,data(1).xmin*-1000);
        clusterEnd = ei_FrameToTime(clusterInd(end)+offset,srate,data(1).xmin*-1000);
%         lh = line([clusterStart clusterEnd],[yMin+(yMax-yMin)*0.1 yMin+(yMax-yMin)*0.1]);
%         xval = clusterStart;
%         yval = yMin+(yMax-yMin)*0.05;
%         text(xval,double(yval),['p=' num2str(clust_info.neg_clust_pval(i))]);
%         set(lh, 'Color',[0 0 1],'LineWidth',3);
        
        disp(['Cluster ' num2str(i) ': ' num2str(round2(clusterStart,0)) 'ms to ' num2str(round2(clusterEnd,0))  'ms,  p = ' num2str(clust_info.neg_clust_pval(i))]);
        
    end
    disp(['POSITIVE CLUSTERS:']);
    posClusterIds = clust_info.pos_clust_ids;
    for i=1:length(clust_info.pos_clust_pval)
        clusterInd = find(posClusterIds==i);
        clusterStart = ei_FrameToTime(clusterInd(1)+offset,srate,data(1).xmin*-1000);
        clusterEnd = ei_FrameToTime(clusterInd(end)+offset,srate,data(1).xmin*-1000);
%         lh = line([clusterStart clusterEnd],[yMin+(yMax-yMin)*0.1 yMin+(yMax-yMin)*0.1]);
%         set(lh, 'Color',[1 0 0],'LineWidth',3);
%         xval = clusterStart;
%         yval = yMin+(yMax-yMin)*0.05;
%         text(xval,double(yval),['p=' num2str(clust_info.pos_clust_pval(i))]);
        
        disp(['Cluster ' num2str(i) ': ' num2str(round2(clusterStart,0)) 'ms to ' num2str(round2(clusterEnd,0))  'ms,  p = ' num2str(clust_info.pos_clust_pval(i))]);
        
    end
    
end


end





