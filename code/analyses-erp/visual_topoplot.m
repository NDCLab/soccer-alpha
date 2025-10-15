function visual_topoplot(filenames, folder, timePoints,maplimits, varargin)
% visual_topoplot() - Plots ERP topographies at specified timepoints.
%            Usually, topographies of difference waves are displayed in 
%            order to find out about the location of ERP effects!
%
% Usage: 
%   >> visual_topoplot(filenames, folder, timePoints, mapLimits, optionalParameters)
% 
%   Mandatory Inputs:
%           filenames   - Files to be plotted as ERP waves
%           folder      - Folder in which the files are located
%           timePoints  - timepoints of the topographies to be plotted 
%                         (e.g., [0:50:500] to plot topographies at
%                         0, 50, 100, 150, 200, ..., 450, 500)                          
%           mapLimits   - Limits of the color scale (e.g., [-5 5] if the
%                         largest amplitude is +5 µV or -5 µV )
%
%   Optional Inputs:
%           'subjects'  - select a sub-range of the total subjects (that
%                         were included in the Grand Averaging). 
%                         CAUTION: Specify subject numbers as they appear
%                         as trials in the Grand Average file (does not
%                         necessarily have to match the original subject
%                         numbers)!
%           'channels'  - Electrodes that are to be displayed
%           'baseline'  - Lets you redefine the baseline period.
%           'mean'      - Plots the topographies not of one specific time
%                         point, but topographies of the mean amplitude of
%                         X ms around the respective timePoints-value (e.g,
%                         topographies at [50 100] are actually
%                         topographies of mean amplitudes from 20-40 and
%                         80-120, if 'mean' = 40 is specified
%
%   Example: 
%   >> visual_topoplot({'diffWave_CorrVsErr'}, 'ResponseLocked_', [0:25:400], [-8 8], ...
%              'subjects', [1:10 12:24], 'channels', [1:64], 'mean', 40 );
%                                         
% (c) 2017 by Robert Steinhauser





inprefix = '';
outprefix = '';
subjects = [];
titleext = [];
baseline = [];
channels = [1:64];
meanTopo = 0;
minTrials = 1;
peakElectrode = [];
peakTimerange = [];
peakMinMax = [];
colormapI = [];


if nargin < 4
    maplimits = [];
end

for i = 1:length(varargin)
    if strcmp(varargin{i}, 'inprefix') 
       if length(varargin)>i  
           inprefix = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''inprefix'' is not valid!');
       end
    end   
    if strcmp(varargin{i}, 'outprefix') 
       if length(varargin)>i  
           outprefix = varargin{i+1}; 
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
        if strcmp(varargin{i}, 'mean') 
       if length(varargin)>i  
           meanTopo = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''mean'' is not valid!');
       end
    end  
    
    if strcmp(varargin{i}, 'baseline') 
       if length(varargin)>i  
           baseline = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''baseline'' is not valid!');
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
    if strcmp(varargin{i}, 'peakTopo') 
       if length(varargin)>i+1  
           peakTimerange = varargin{i+1};
           peakMinMax = varargin{i+2};
       else
           disp('ERROR: Input for parameter ''peakTopo'' is not valid!');
       end
    end      
    if strcmp(varargin{i}, 'colormap') 
       if length(varargin)>i  
           colormapI = varargin{i+1}; 
       else
           disp('ERROR: Input for parameter ''colormap'' is not valid!');
       end
    end     
    
    
end


lowTrialSubjects = [];
for i = 1 : length(filenames)  
    data = pop_loadset('filename',[ filenames{i} '.set'],'filepath',folder);
    if ~isempty(baseline)
        data = pop_rmbase(data,baseline);
    end
    
    if ~isempty(subjects)
        data = pop_select(data,'trial',subjects);
        
        if length(subjects) == 1
            titleext = [' (' num2str(subjects) ')'];
        end

    end
    
    if ~isempty(minTrials)
        e = data.event;
        trials = [e(:).trials];    
        trials(trials<minTrials) = -1;
        lowTrialSubjects = unique([lowTrialSubjects find(trials == -1)]);    
        data = pop_select(data,'notrial',lowTrialSubjects);
    end   

    
    
    if meanTopo~=0
        for iTime = 1 : length(timePoints)
            a1 = (timePoints(iTime) - floor(meanTopo/2));
            a2 = (timePoints(iTime) + floor(meanTopo/2));
            area = [ei_TimeToFrame(a1,data.srate,abs(data.xmin*1000)) : ei_TimeToFrame(a2,data.srate,abs(data.xmin*1000)) ];
            d1 = data.data(:,area,:);
            d2 = mean(d1,2);
            for i2 = area
                data.data(:,i2,:) = d2;
            end
        end
        
    end
    
 
    if ~isempty(peakTimerange)
        
        for iVP = 1:size(data.data,3)
            currData = squeeze(data.data(1:64,ei_TimeToFrame(peakTimerange(1),data.srate,data.xmin*-1000):ei_TimeToFrame(peakTimerange(2),data.srate,data.xmin*-1000)   ,iVP));
            
            if strcmp(peakMinMax,'min')
                [val pos1] = min(currData,[],1);
                [val2 pos2] = min(val);
            elseif strcmp(peakMinMax,'max')
                [val pos1] = max(currData,[],1);
                [val2 pos2] = max(val);
            else
               error('Error: Choose min or max') 
            end
           
            
          if isempty(meanTopo)
              d = data.data(1:64,ei_TimeToFrame(peakTimerange(1),data.srate,data.xmin*-1000)+pos2,iVP); 
          else
              ma = ei_TimeToFrame(meanTopo,data.srate,0);
              d = data.data(1:64,ei_TimeToFrame(peakTimerange(1),data.srate,data.xmin*-1000)+pos2-floor(ma/2) : ...
                                 ei_TimeToFrame(peakTimerange(1),data.srate,data.xmin*-1000)+pos2+floor(ma/2),iVP); 
              d = mean(d,2);
          end
          
          
            
            
           
         
          selectData(:,1,iVP) = d; 
          
          peakTimepoints(iVP) = ei_FrameToTime(ei_TimeToFrame(peakTimerange(1),data.srate,data.xmin*-1000)+pos2,data.srate,data.xmin*-1000);
        
        end
        
      
         meanData  = mean(selectData,3); 
         figure();
         subplot(1,2,1);
         plot(peakTimepoints);
         
         subplot(1,2,2);
%          topoplot(meanData,data.chanlocs,'electrodes','on','maplimits',maplimits,'whitebk','on','plotchans',channels,'intrad',0.505,'plotrad',0.5);
        topoplot(meanData,data.chanlocs,'electrodes','on','maplimits',maplimits,'whitebk','on','plotchans',channels,'intrad',0.505);
          
%            pop_topoplot(data,1, timePoints ,[data.setname titleext],[1,length(timePoints)],0,'electrodes','on','maplimits',maplimits,'whitebk','on','plotchans',channels,'intrad',0.505);
%  
             
        
        
    else
        
        
        if size(timePoints)<2
            figure();
        end;
        
%         if size(timePoints)<10
%             pop_topoplot(data,1, timePoints ,[data.setname titleext],[1,length(timePoints)],0,'electrodes','on','maplimits',maplimits,'whitebk','on','plotchans',channels,'intrad',0.505);
%         else
%             pop_topoplot(data,1, timePoints ,[data.setname titleext],0 ,0,'electrodes','on','maplimits',maplimits,'whitebk','on','plotchans',channels,'intrad',0.505);
%         end
        
        if isempty(colormapI)
            cm = jet;
        else
            cm = colormapI;
        end
     
        if size(timePoints)<10
            pop_topoplot(data,1, timePoints ,[data.setname titleext],[1,length(timePoints)],0,'electrodes','on','maplimits',maplimits,'whitebk','on','plotchans',channels,'intrad',0.50,'plotrad',0.5,'colormap', cm);
           
        else
            pop_topoplot(data,1, timePoints ,[data.setname titleext],0 ,0,'electrodes','on','maplimits',maplimits,'whitebk','on','plotchans',channels,'intrad',0.50,'plotrad',0.5);
        end        
        colormap(cm);
        
       
    end
    
    
    
    
end