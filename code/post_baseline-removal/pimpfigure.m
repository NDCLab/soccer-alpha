function pimpfigure(type,varargin)
% pimpfigure(type) - Automatically makes your picture as pretty as a butterfly.
%                    Currently works for Grand Average ERP images, ERP topographies,
%                    line charts and bar charts.
%
%  type: 1 / 'ERP'
%        2 / 'TOPO'
%        3 / 'LINE' (TO BE IMPLEMENTED)
%        4 / 'BAR'  (TO BE IMPLEMENTED)
%
% ERP GRAND AVERAGE WAVEFORM
%   >> pimpfigure(1, limits, lineStyles, legend, testArea,colors)
%   >> pimpfigure('ERP', limits, lineStyles, legend, testArea,colors)
%
% Inputs:
%      limits      - [xMin xMax yMin yMax] Define the limits for the
%                    X-axis and Y-axis. If left empty, X-axis is limited 
%                    to [-200 end] and Y-axis is limited to the largest
%                    positive and negative peak (+a 10% buffer)
%      lineStyles  - Define an individual line style for each of the
%                    ERP waves. In addition to standard MATLAB formatting, 
%                    an additional digit can specify the line width.
%                    Examples:     b      - solid blue line (default 6 px)
%                                  r:     - dotted red line (default 6 px)
%                                  g3     - solid green 3 px line 
%                                  y-1    - yellow dashed 1 px line 
%                    If left empty: depending on the number of conditions,                         
%                    hopefully useful combinations are chosen (up to 3:
%                    b/r/g, 4: b/b:/r/r:, 8: b/b:/r/r:/b3/b:3/r3/r:3 )
%      legend      - Define labels for the conditions legend. If left empty, 
%                    default set names are taken. 
%                    Example: {'Correct'  'Error'}                         
%      testArea    - [x1 x2] A grey rectangle can be inserted that represents,
%                    e.g., the time interval taken for significance testing
%      colors      - RGB values (e.g., [0 176 80; 255 102 0; 255 192 0; 204 0 0])
%
% ERP TOPOGRAPHY
%   >> pimpfigure(2, colormap)
%   >> pimpfigure('TOPO', colormap)
%
% Inputs:    
%      colormap    - Define the color mapping of the topographies.
%                    1: Jet (Default)
%                    2: Gray
%                    3: Hot
%                    4: HSV
%
% LINE CHART
%   >> pimpfigure(3, limits, axesTitles, yLabels, legend, lineStyles, title)
%   >> pimpfigure('LINE', limits, axesTitles, yLabels, legend, lineStyles, title)
%
%      [[ TO BE IMPLEMENTED ]]
%
% BAR CHART
%   >> pimpfigure(4, axesTitles, xLabels, legend)
%   >> pimpfigure('BAR', axesTitles, xLabels, legend)
% 
%      [[ TO BE IMPLEMENTED ]] 
% 
% 
%  (c) Robert Steinhauser 2017
%


if ~ischar(type)
    t = type;
    switch t
        case 1
            type = 'ERP';
        case 2
            type = 'TOPO';
        case 3
            type = 'LINE';
        case 4
            type = 'BAR';
    end
            
    
end

set(gcf,'color','white');


if strcmp(upper(type),'ERP')
    
    
     lineCount = 0;
    ax=findall(gcf,'Type','line');
    for iLine = 1 : length(ax)
        if ~isempty(get(ax(iLine),'DisplayName'))
            uistack(ax(iLine),'top');
        end        
    end    
    
    lineCount = 0;
    ax=findall(gcf,'Type','line');
    for iLine = 1 : length(ax)
        if ~isempty(get(ax(iLine),'DisplayName'))
%             disp(get(ax(iLine),'DisplayName'));
          lineCount = lineCount + 1;
        end        
    end    
    
    if nargin < 2 || isempty(varargin{1})
        % Compute estimated limits
    ax=findall(gcf,'Type','line');
    c = 1;
    for iLine = 1 : length(ax)
        if ~isempty(get(ax(iLine),'DisplayName')) 
          ymax(c) = max(get(ax(iLine),'YData'));
          ymin(c) = min(get(ax(iLine),'YData'));
          xmax(c) = max(get(ax(iLine),'XData'));
          c = c + 1;
        end        
    end        
        effectSize = max(ymax)-min(ymin);
        
        limits = [-200 max(xmax) min(min(ymin)-(0.1*effectSize),-1) max(ymax)+(0.2*effectSize)];
    else        
        limits = varargin{1};
        ax=findall(gcf,'Type','line');
        c = 1;
        for iLine = 1 : length(ax)
            if ~isempty(get(ax(iLine),'DisplayName'))
                ymax(c) = max(get(ax(iLine),'YData'));
                ymin(c) = min(get(ax(iLine),'YData'));
                xmax(c) = max(get(ax(iLine),'XData'));
                c = c + 1;
            end
        end
    end
    
    if nargin < 3
        lineStyles = [];
        if lineCount < 4
            lineStyles = {'b' 'r' 'g'};
        elseif lineCount == 4
            lineStyles = {'b' 'b:' 'r' 'r:'};
        elseif lineCount == 8
            lineStyles = {'b' 'b:' 'r' 'r:' 'b2' 'b:2' 'r2' 'r:2' };
        else
            
        end
    else
        lineStyles = varargin{2};
    end
    
    if nargin < 4
        legendEntries = [];
    else
        legendEntries = varargin{3};
    end    
    if nargin < 5
        rect = [];
    else
        rect = varargin{4};
    end  
    if nargin < 6
       colors = []; 
    else
        colors = varargin{5};
    end
    
    
    
    set(gca,'LineWidth',2,'FontSize',24,'FontName','Arial');
    %set(plot1(1),'Color',[0 0 1],'DisplayName','#1 correct mixed (n=26)');
    
    % Set width of all lines
    ax=findall(gcf,'Type','line');    
    for iLine = 1 : length(ax)
        set(ax(iLine),'LineWidth',5);
        if ~isempty(get(ax(iLine),'DisplayName')) % If one of the data lines
            set(ax(iLine),'LineWidth',6);
        else                                      % If one of the axis lines
            set(ax(iLine),'LineWidth',2);
        end        
    end
    
     % Set X and Y limitations  
    set(gca,'xlim',limits(1:2),'ylim',limits(3:4));
    
    % Set font of axis titles
    ax=findall(gcf,'Type','text');
    c = 1;
    for iLine = 1:length(ax);
%         disp(get(ax(iLine),'String'));
        set(ax(iLine),'FontSize',24,'FontName','Arial');
        s = get(ax(iLine),'String');
        if ~strcmp(s,'Potential (\muV)') && ~strcmp(s,'Time (ms)') && length(s)<8 && length(s)>1
            e = get(ax(iLine),'extent');
            set(ax(iLine),'Position',[limits(1)+e(3) limits(4)-e(4) 0]);
%             set(ax(iLine),'Position',[0+e(3) 0-e(4) 0]);
            
        end
        
%         if ~isempty(get(ax(iLine),'DisplayName')) % If one of the data lines
%             set(ax(iLine),'DisplayName',legendEntries{c});
%             c = c + 1;
%         end
    end
    
   
    % Set line styles
    if ~isempty(lineStyles)
        ax=findall(gcf,'Type','line');
        c = 1;
        for iLine = 1 : length(ax);
            if ~isempty(get(ax(iLine),'DisplayName')) % If one of the data lines
                ls = lineStyles{c};
                
                disp('D');
                if isempty(str2num((ls(1))))                
                    set(ax(iLine),'Color',ls(1))
                else
                    col = colors(str2num(ls(1)),:) ./ 255;
                    set(ax(iLine),'Color',col);
                    
                end
                
                
                
                if length(ls)>1
                    if ~isempty(str2num(ls(2)))
                        set(ax(iLine),'LineWidth',str2num(ls(2)));
                    else
                        set(ax(iLine),'LineStyle',ls(2));
                    end
                end
                if length(ls)>2
                    set(ax(iLine),'LineWidth',str2num(ls(3)));
                end
                c = c + 1;                
            end
        end
    end
    
    
    
    
    % Set legend entries
    if ~isempty(legendEntries)
        ax=findall(gcf,'Type','line');
        c = 1;
        for iLine = 1:length(ax);
            if ~isempty(get(ax(iLine),'DisplayName')) % If one of the data lines
                set(ax(iLine),'DisplayName',legendEntries{c});
                c = c + 1;
            end       
        end
    end
    
    %%%% version-based differences %%%
    
    v = ver;
    
  %  if str2num(v(1).Version) > 8.3 % Roberts Version
        %turn around labels
        labels = get(legend(), 'String');
        labelnr = numel(labels);
        fllabels = fliplr (labels);

        
        plots = get(gca, 'children');
        
        lines = plots( 1 : labelnr,1)
        
        legend([lines], fllabels);
 %   end
    
    
    
    % delete nonneeded lines
    ax=findall(gcf,'Type','line');
    for iLine = 1:length(ax);
%         disp(mat2str(get(ax(iLine),'YData')));
        xd = get(ax(iLine),'XData');
        if isempty(get(ax(iLine),'DisplayName')) && xd(1)==-100 && xd(2)==100
            set(ax(iLine),'LineStyle','none');
        end
        yd = get(ax(iLine),'YData');
        if isempty(get(ax(iLine),'DisplayName')) && round2(xd(1),1)==round2(max(xmax),1) && round2(xd(2),1)==round2(max(xmax),1)
            set(ax(iLine),'LineStyle','none');
        end
        if isempty(get(ax(iLine),'DisplayName')) && xd(1)==0 && xd(2)==0
            set(ax(iLine),'YData',[-100 100]);
        end
        if isempty(get(ax(iLine),'DisplayName')) && yd(1)==0 && yd(2)==0
            set(ax(iLine),'XData',get(ax(iLine),'XData')*10);
        end
        
    end
    
    % create rectangle for significance window
    if ~isempty(rect)
        if iscell(rect)
            for iR = 1:length(rect)
                h = rectangle('Position',[rect{iR}(1) limits(3)+0.02 (rect{iR}(2)-rect{iR}(1)) limits(4)-limits(3)-0.02]);
                set(h,'FaceColor',[0.9 0.9 0.9],'LineStyle','none');
                uistack(h,'bottom');
            end
            
        else
            h = rectangle('Position',[rect(1) limits(3)+0.02 (rect(2)-rect(1)) limits(4)-limits(3)-0.02]);
            set(h,'FaceColor',[0.9 0.9 0.9],'LineStyle','none');
            uistack(h,'bottom');
            
        end
    end
    
    
    
end

if strcmp(upper(type),'TOPO')
    
    ax=findall(gcf,'Type','text');
    for iLine = 1 : length(ax)
        set(ax(iLine),'FontSize',20);     
    end   
    
    lineCount = 0;
    ax=findall(gcf,'Type','axes');
    for iLine = 1 : length(ax)
        xd = get(ax(iLine),'YTickLabel');
        if length(xd) == 5
          
          set(ax(iLine),'FontSize',20);
          p = get(ax(iLine),'Position');
          pNew = p;
          pNew(2) = p(2) + (((1-0.4)*p(4))/2);
          pNew(3) = 0.025;
          pNew(4) = 0.4 * p(4);
          set(ax(iLine),'Position',pNew);
        end
%         set(ax(iLine),'FontSize',20);     
    end       
    
    if nargin < 2
        colMap = 1;
    elseif isempty(varargin{1});
        colMap = 1;
    else
        colMap = varargin{1};
    end
    
    switch colMap 
        case 1        
            colormap('Jet');
        case 2        
            colormap('gray');
        case 3        
            colormap('Hot');
        case 4        
            colormap('HSV');
    end
    
    
    
    
end


if strcmp(upper(type),'LINE')    
      
   set(gca,'FontSize',24,'FontName','Arial','LineWidth',2); 
   
   ax=findall(gca,'Type','line');
   for iL = 1 : length(ax)
       disp(length(get(ax(iL),'XData')));
       lines(iL) = length(get(ax(iL),'XData'));
   end
   
   [a mi] = min(lines);
   lineCount = length(find(lines == a));  
   condX = get(ax(mi(1)),'XData');
   xCound
   
   
   if nargin < 2 || isempty(varargin{1}) 
        limits = [];
    else
        limits = varargin{1};
   end
   
   if nargin < 3 || isempty(varargin{2})
       axesTitles = [];
   else
       axesTitles = varargin{2};
   end
   
   
   if nargin < 4 || isempty(varargin{3})
       xLabels = [];
   else
       xLabels = varargin{3};
   end
      
   if nargin < 5 || isempty(varargin{4})
       legendLabels = [];
   else
       legendLabels = varargin{4};
   end
   
   if nargin < 6 || isempty(varargin{5})
       lineStyles = {'b' 'r' 'g' 'k' 'b:' 'r:' 'g:' 'k:' 'b-' 'r-' 'g-' 'k-'};
   else
       lineStyles = varargin{5};
   end

   if nargin < 7 || isempty(varargin{6})
       imgTitle = [];
   else
       imgTitle = varargin{6};
   end
   
   if ~isempty(limits)
       set(gca,'XLimits',limits(1:2),'YLimits',limits(3:4));
   end
   
   if ~isempty(axesTitles)
       xlabel(axesTitles{1});
       ylabel(axesTitles{2});
   end
   
   if ~isempty(xLabels)
       % wenn Tick-Anzahl nicht mit yLabel-Länge übereinstimmt, dann finde
       % die eigentlichen Ticks heraus      
       ticks = get(gca,'XTick');       
       if length(ticks) ~= lineCount
          set(gca,'XTick',condX);          
       end
       set(gca,'XTickLabel',xLabels);           
   end
   
   
   
%    lineStyles = {'b' 'r'};
   c = 0;
   ax=findall(gca,'Type','line');
   for iL = 1 : length(ax)
       set(ax(iL),'LineWidth',3);
       xs = length(get(ax(iL),'XData'));
       
       
       if xs == lineCount
           c = c + 1;
           ls = lineStyles{c};
           
           
       end
       
       if length(condX) <5
           
           p = get(ax(iL),'XData');
           p = p - (c-2)*0.02;           
           set(ax(iL),'XData',p);
       end
       
       set(ax(iL),'Color',ls(1));
       if length(ls)>1 && isempty(str2num(ls(2)))
           set(ax(iL),'LineStyle',ls(2));
       end
       if length(ls)>1 && ~isempty(str2num(ls(2)))
           set(ax(iL),'LineWidth',str2num(ls(2))),
       end
       if length(ls)>2
           set(ax(iL),'LineWidth',str2num(ls(3)));
       end
       
       
      
       
%        set(ax
       
   end
     
  
end

if strcmp(upper(type),'BAR')
    %  ('BAR', axesTitles, xLabels, colors, legend)
    
    % Y-Limits
    ax=findall(gcf,'Type','Patch');
    ys = get(ax,'YData');
    for i = 1:length(ys)
        ys{i}(ys{i}==0) = [];
        maxy(i) = max(max(ys{i}));
        miny(i) = min(min(ys{i}));
    end
    effectSize = max(maxy)-min(miny);
    
    ma = max(maxy)+0.3*effectSize;
    mi = min(miny)-0.3*effectSize;
    set(gca,'ylim',[mi ma]);
    
    % Line Thickness
    set(gca,'LineWidth',2,'FontSize',24,'FontName','Arial');
    ax=findall(gca,'Type','line');
    for iL = 1 : length(ax)
        set(ax(iL),'LineWidth',2);
    end
    
    % Axes Titles
    if nargin < 2 || isempty(varargin{1})  
        
    else
       titles = varargin{1};
       xlabel(titles{1});
       ylabel(titles{2});       
    end
    
    % X-Labels
    if nargin < 2 || isempty(varargin{2})
        xLabels = [];
    else
        xLabels = varargin{2};
    end
     if ~isempty(xLabels)
       % wenn Tick-Anzahl nicht mit yLabel-Länge übereinstimmt, dann finde
       % die eigentlichen Ticks heraus      
       ticks = get(gca,'XTick');       
%        if length(ticks) ~= lineCount
%           set(gca,'XTick',condX);          
%        end
       set(gca,'XTickLabel',xLabels);           
     end
   
     % Colors
    if nargin < 3 || isempty(varargin{3})
        colors = [];
    else
        colors = varargin{3};
    end
    if ~isempty(colors)
        ax=findall(gca,'Type','Patch');
        
        rgbcolors = [];
        for i=1:length(colors)
            c = colors{i};
            rgbcolors = [rgbcolors; rgb(c(1))];
        end
        
        
%         mycolor = rgbcolors;
%         
%         
%          set(ax,'CDataMapping','direct');
%         
% %          set(ax, 'CData',mycolor);
%         colormap(mycolor);
        
        
        for iL = 1 : length(ax)      
%             mycolor = rgbcolors;
%             %colormap(mycolor);            
%             set(ax(iL),'CDataMapping','direct');
%             
%             set(ax(iL), 'CData',[1:length(colors)]);
%             colormap(mycolor);
%             
            c = colors{length(ax)+1-iL};
            %set(ax(iL),'FaceColor',c(1));
            if length(c) == 1
               set(ax(iL),'LineStyle','-');
                  set(ax(iL),'LineWidth',2); 
            end
            
            if length(c)==2
                if strcmp(c(2),'-')
                  set(ax(iL),'LineStyle','--');
                  set(ax(iL),'LineWidth',2);
                elseif strcmp(c(2),':')
                  set(ax(iL),'LineStyle',':');
                  set(ax(iL),'LineWidth',2);
                end
            end
        end
        
    end
    
    % Legend
    if nargin < 4 || isempty(varargin{4})
        legendStrings = [];
    else
        legendStrings = varargin{4};
        legendStyles = varargin{5};
    end
    if ~isempty(legendStrings)
        h = zeros(length(legendStrings),1);
        for i=1:length(legendStrings)
           st = legendStyles{i}; 
           h(i) = bar(NaN,NaN,st(1)); set(h(i),'LineWidth',2); 
             if length(st)>1
                 if strcmp(st(2),'-')
                    set(h(i),'LineStyle','--'); 
                 elseif strcmp(st(2),':')
                    set(h(i),'LineStyle',':');   
                 end
                     
             end
            
        end
        legend(h,legendStrings);
        
        
    end
    
end

