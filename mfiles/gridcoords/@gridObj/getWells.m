function [well,WEL,PNTSRC]=getWells(gr,basename,wellOrSheetNm,HK,QsheetNm,CsheetNm,nrs)
% [well,WEL,PNTSRC]=gr.getWells(basename,wellOrSheetNm,HK,nrs)
%
%  replaces old gr.well as getWells better reflects what the methods does.
%
% GridObj.well sets this well into grid gr, where gr is of class gridObj.
%
% GridObj.well further ..
%   Looks for column Q_n with n=well number for Q(t) of this well.
%   Looks for column Cn_m with n=well number and m=species nr for
%   time-dependent injection concentration for this well.
%   The latter is only requested if PNTSRC is speciied as output.
% INPUT:
%   well_or_wellSheetName is either an array of wellObj or the name of the
%      worksheet in workbook basename where the pertinent data of the wells
%      are specified in a simple table.
%   HK is the 3D array of horizontal conductivities or transmissivities to
%      allow compuation of the fraction of the well flow to be attributed to
%      any cell penetrated by the well screen.
%   basename if the baasename of this problem used as the name or all files
%      generated by this problem and specified in mf_adapt.
%
% OUTPUT
%   well = array of wellObj instances according the the input or the
%      specification on sheet well of workbook <<basename>>.xls.
% WEL  = mfLab intput for the well package.
%    The well flows are looked up in the PER worksheet in the columns with
%    header Q_n where n is the well number as specified explicitly in the well
%    worksheet.
% PNTSRC = mfLab input for pointsources in SSM package of MT3DMS or SEAWAT.
%    To generate PNTSRC, the concentration for the stress periods for the wells
%    have to be specified as columns in the PER worksheet in <<basename>>.xls.
%    The headers of these columns are Cm_n where m is the well number and n the
%    species number.
%
%    If PNTSRC is required, the concentratons for each well must be specified
%    in columns of the PER sheet named C1_1 C2_1 C3_1 etc. for concentrations
%    of component 1, C1_2 C2_2 C3_2 for component two etc.
%
%    There must be no other names starting with C1_ C2_ etc in the PER worksheet.
%
% SEE ALSO: gridObj/setWell wellObj/WEl wellObj/PNTSRC mfSetWells
%
%   TO 110426 120103 120408
%
% Copyright 2009-2012 Theo Olsthoorn, TU-Delft and Waternet, without any warranty
% under free software foundation GNU license version 3 or later


%% Check input item wellOrSheetNm

if ischar(wellOrSheetNm)
    % sheetNm is the name of the spreadsheet holding with table of wells
    sheetNm = wellOrSheetNm;
    
    % generate wells form scratch
    well = wellObj(basename,sheetNm);
    
else
    well = wellOrSheetNm;
    
    % check to see that the input is indeed of class wellObj
    if ~(strcmpi(class(well),'wellObj') || strcmpi(class(well),'MNW1Obj'))
        error('mf_setwells:input:wellInput',...
            '%s: input well|wellsheetname  must be either char or wellObj or MNW1Obj',mfilename);
    end
end


%% Put the wells in the model grid using the gridObj and the HK or TRAN
% Putting the wells into the grid implies computing the grid coordinates
% for each well and other data that emerge when combining the real-world
% object well into the model grid that contains the information about the
% cells of the model and their coordinates. It will use HK (or TRAN) to
% compute the fraction extracted from each cell penetrated by the well
% screen. The output objects are equal to the input objects but with the
% grid information added.

if exist('HK','var') 
    well=well.setWell(gr,HK);
    if isempty(well)
        error(['No wells found or left!',...
            ' Probable cause: all wells fall out of the model boundaries.\n',...
            'Check their coordinates and those of the model grid itself.']);
    end
end

%% If no stress period data is required, then finish.
if nargout<2, return; end

%% ================ At this point the WEL is requested ====================

%% Generating the input for the WEL package
% the mfLab input for the WEL package is the same as the modflow input
% except that the first column is the stress period number to make the
% lines unique and to allow any order of the input in mfLab. mfLab will
% sort the output to match the modflow requirements.

[pernams,pervals,NPER]=getPeriods(basename);

%% THE COLUMNS IN THE PER SHEET REFERRING TO THE WELLS MUST BE NAMED Q_n where n is the well number!
% The first action is to verify that such a column exists for every well in
% the input. Note that different wells may have the same number. In that
% case they will get their flow data from the same column in the PER
% worksheet.

QCOL=NaN(size(well));

for iw=1:length(well)
    % Geneate the names of the columns in the PER worksheet: Q_1, Q_2 Q_3 etc.
    qstr=sprintf('Q_%d',well(iw).nr);
    
    % Look up the column number with the time-flow data for each wel in sequence
    QCOL(iw)=strmatchi(qstr,pernams,'exact');
    
    % If absent --> error
    if QCOL(iw)==0
        error('mf_setwells:QCol:PER',...
            'No Q column <<%s>>in sheet PER for well Nr %d',qstr,well(iw).nr);
    end
end

%% Having verified all data columns are present, we will add the data pertaining to each well to the well object itself.
% Hence each well will carry its own flow data for all stress periods. At
% the same time it carries the length of each stress period to allow
% computing total mass in or out of the well. Finally it carries the time
% of the end of the stress periods.

Dt=pervals(:,strmatchi('PERLEN',pernams));

for iw=1:length(well)
    
    well(iw).Q  = pervals(:,QCOL(iw))'; % as a horizontal vector for easy inspection

%     if any(isnan(well(iw).Q))
%         error('mf_setwells:pervals:QhasNaN',...
%             '%s.Q has NaN(s), check worksheet PER column <<Q_%d>> for missing Q data!\n',well(iw).name,well(iw).nr);
%     end

    well(iw).Dt = Dt';
    
    % set well t. Note that this may be overruled by well.setCout(C,iComp).
    well(iw).t  = cumsum(well(iw).Dt,2);
end


%% Step 1, count how many well cells we have.
% We generally have more than one well cell per well screen. Therefore,
% we must count the total number of well cells before allocating
% memory.

N=0; % Number of well cells
for iw=1:length(well)
    N=N+size(well(iw).LRC,1);
end

%% All wells carry their grid  info and fow info. So we can proceed with WEL

% Step 2: Allocate memory to hold LRC and Q for all these cells
LRC         = NaN(N,3);    % Store LRC
Q           = NaN(N,NPER); % Store flow for cells and stress period
wellNr      = NaN(N,1);    % Well Nr

%% Step 3: Populate these arrays
k=0;
for iw=1:length(well)
   if size(well(iw).Q,2) ~= NPER
       error('wellObj:WEL:NoNPERQvalues',...
           'well %d (well Id=%d) does not have NPER Q values.',iw,well(iw).id);
   end

   m = size(well(iw).LRC,1);
   LRC(   k+(1:m),:)=well(iw).LRC;
   Q(     k+(1:m),:)=well(iw).fQ(:) * well(iw).Q;
   wellNr(k+(1:m),1)=well(iw).nr;
   k=k+m;
end

%% Step 4: Generate WEL cells if requested

WEL{NPER,1} = {};          % Allocated memory
for iPer=1:NPER
    %% If nargin>1 used to signal that well Nr will be added to each line of WEL
    if nargin>1,
        WEL{iPer} = [ ones(N,1)*iPer LRC Q(:,iPer)]; % wellNr];
    else
        WEL{iPer} = [ ones(N,1)*iPer LRC Q(:,iPer)];
    end
    WEL{iPer} = WEL{iPer}(~isnan(Q(:,iPer)) & Q(:,iPer)~=0, :);
end

WEL=WEL(~cellfun('isempty',WEL));

if nargout==2; return; end



%% ============== At this point the PNTSRC are requested ==================

%% At this point PNTSRC is required for the SSM package used by MT3DMS or SEAWAT
% We will generate the PNTSRC and the WEL arrays jointly for efficiency.

%% First thing is to know how many species (compoments) we deal with.
% For this we need the information form the MT3D worksheet. It contains the
% NCOMP and MCOMP parameter values. MCOMP is the total number of species
% in the simulation. The input must have this number of specified
% concentrations.

[MT3nams,MT3vals]=getExcelData(basename,'MT3D','vertical');
NCOMP=MT3vals(strmatchi('NCOMP',MT3nams),1);

%%%%% THE COLUMNS IN THE PER SHEET REFERRING TO CONCENTRATIONS MUST BE
%%%%% NAMED AS FOLLOWS  C%d_%d where the first %d is the well number and
%%%%% the second %d the species number: i.e.
%%%%% C1_1 C1_2 C1_3 C2_1 C2_2 C2_3 for three species and two wells

%% Find the columns in worksheet PER holding the concentrations for the well
% While looking for the respective columns in the PER worksheet. Add NCOMP
% to the well and allocate the required space to hold the input and the
% output concentrations of each well.
% The output concentrations can be set suing wellObj.setCout after the simulation
% when the model-computed concentrations are available.

for iw=1:length(well)
    well(iw).NCOMP=NCOMP;
    well(iw).C = NaN(NCOMP,NPER);
%    well(iw).Cout=NaN(size(well(iw).C)); % out conc for other application
 
    for iComp=1:NCOMP
        % Column header Cm_n (m=wellNr, n=species nr)
        cstr=sprintf('C%d_%d',well(iw).nr,iComp);
        
        % Look for this column header in the PER sheet
        CCOL=strmatchi(cstr,pernams,'exact');
        if iComp==1 && CCOL==0
            % if NCOMP==1 allow C_n with n well number
            cstr=sprintf('C_%d',well(iw).nr);
            CCOL=strmatchi(cstr,pernams,'exact');
            if CCOL==0
                % If this doesn't work, allow Cn with n well number if NCOMP=1
                cstr=sprintf('C%d',well(iw).nr);
                CCOL=strmatchi(cstr,pernams,'exact');
            end
        end
        if CCOL==0 % However, the corresponding column in the PER sheet must exist !
            error('wellObj:well:CCOLnotfound',...
                ['Can''t find well-concentration column header <<%s>>for component %d well %d in PER worksheet,\n',...
                'Make sure your concentration column headings are "Ca_b" where a=species number and b=well number.\n',...
                'Well number corresponds to the number in the sheet where you specified your wells including\n',...
                'their well numbers. So the well number is specified by you independently of mfLab.\n'],...
                cstr,iComp,well(iw).nr);
        end
        
        % Plug intput concentration C into well object as a horizontal vector
        % one for each compoment. Horizontal vectors are easy viewed when typing the name of the object.
        well(iw).C(iComp,:) =pervals(:,CCOL)';
    end
end


%% PNTSRC array required by SSM package
% At this point we have ensured that every well has both its flow data and
% its input concentration on board. So we can compute the mflab version of
% the the well package input WEL and the mflab version of the SSM package
% input PNTSRCR simultanously.

ITYPE = 2; % ITYPTE for WEL
    
if NCOMP>1, nCol=6+NCOMP; else nCol=6; end

%% Step 1, cell counting has already been done for WEL

%% Step 2: Allocate memory. LRC has alread been filled above

C = NaN(N,NPER,NCOMP);   % Store flow for cells and stress period
  
%% Step 3: Populate these arrays
k=0;
for iw=1:length(well)
   if size(well(iw).C,2) ~= NPER
       error('wellObj:PNTSRC:NoNPERQvalues',...
           'well %d (well Id=%d) does not have NPER C values.',iw,well(iw).id);
   end

   m = size(well(iw).LRC,1);
   for iComp=1:NCOMP
      C(  k+(1:m),:,iComp)=ones(size(well(iw).fQ(:))) * well(iw).C(iComp,:);
   end
   k=k+m;
end
    
%% Step 4: Generate PNTSRC cells
PNTSRC{NPER,1}=NaN(N,nCol);  % One cell array per stress period

for iPer=1:NPER
    if NCOMP==1
        PNTSRC{iPer} = [ ones(N,1)*iPer LRC C(:,iPer,1) ones(N,1)*ITYPE ];
    else
        PNTSRC{iPer} = [ ones(N,1)*iPer LRC C(:,iPer,1) ones(N,1)*ITYPE squeeze(C(:,iPer,:)) ];
    end
    % Remove stress periods without flow
    PNTSRC{iPer} = PNTSRC{iPer}(~isnan(Q(:,iPer)) & Q(:,iPer)~=0, :);

end

PNTSRC=PNTSRC(~cellfun('isempty',PNTSRC));

% done



