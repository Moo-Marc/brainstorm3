function varargout = panel_realtime(varargin)
% PANEL_REALTIME: Create a panel to guide realtime feedback and headposition measurements.
% 
% USAGE:  bstPanelNew = panel_realtime('CreatePanel')
%                       panel_realtime('UpdatePanel')
%                       panel_realtime('CurrentFigureChanged_Callback')

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2020 University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, Elizabeth Bock, 2010-2016

eval(macro_method);
end

%% ===== CREATE PANEL =====
function bstPanelNew = CreatePanel() 
    panelName = 'Realtime';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import org.brainstorm.list.*;
    
    % Main panel container
    jPanelNew = java_create('javax.swing.JPanel');
    jPanelNew.setLayout(BoxLayout(jPanelNew, BoxLayout.PAGE_AXIS));
    jPanelNew.setBorder(BorderFactory.createEmptyBorder(10,10,0,10));
    
    % ===== PANEL: SUBJECT OPTIONS =====
    jPanelSubject = gui_river([0,1], [2,4,4,0], 'Subject');
        gui_component('label', jPanelSubject, 'br', 'Subject: ');
        jTextCurSubject = gui_component('text', jPanelSubject, 'hfill', '');
        jButtonRegisterSubject = gui_component('button', jPanelSubject, 'br', 'Register subject', [], [], @RegisterSubject_Callback);
        jButtonAddHeadpoints = gui_component('button', jPanelSubject, 'br', 'Add Headpoints', [], [], @AddHeadPoints_Callback);        
    jPanelNew.add(jPanelSubject);
    
    % ===== PANEL: FIELDTRIP BUFFER =====
    jPanelFT = gui_river([0,1], [2,4,4,0], 'Fieldtrip Buffer');
        % FT Buffer setup
        gui_component('label', jPanelFT, [], 'Fieldtrip buffer host: ');
        jTextFTHost = gui_component('text', jPanelFT, 'hfill', ' ');
        gui_component('label', jPanelFT, 'br', 'Fieldtrip buffer port: ');
        jTextFTPort = gui_component('text', jPanelFT, 'hfill', ' '); 
        jButtonInitFT = gui_component('button', jPanelFT, 'br', 'Start buffer', [], [], @InitFieldtripBuffer_Callback);
    jPanelNew.add(jPanelFT); 
    
    % ===== PANEL: DATA OPTIONS =====
    jPanelOptions = gui_river([0,1], [2,4,4,0], 'Realtime Collection');
        % Data chunk length in ms
        gui_component('label', jPanelOptions, [], 'Block size: ' );
        jTextBlock = gui_component('texttime', jPanelOptions, 'tab', ' ');
        gui_component('label', jPanelOptions, [], ' ms');
                
        gui_component('Label', jPanelOptions, 'br', ' ');
        gui_component('label', jPanelOptions, 'br', 'Max head movement: ');
        jTextMovement = gui_component('texttime', jPanelOptions, 'tab', ' '); 
        gui_component('label', jPanelOptions, [], ' mm');
        
    jPanelNew.add(jPanelOptions);

    % ===== PANEL: FEEDBACK OPTIONS =====
    jPanelFeedback = gui_river([0,1], [2,4,4,0], 'Feedback Options');
        
        jButtonGroupDisplayType = ButtonGroup();
        jRadioCortexDisplay = gui_component('Radio', jPanelFeedback, 'br', 'Cortex Display Demo', jButtonGroupDisplayType, 'Display source maps on cortical surface');
        jRadioOtherDisplay = gui_component('Radio', jPanelFeedback, 'br', 'Other', jButtonGroupDisplayType, 'Save index to a file for use with external display');
        jTextFunction = gui_component('text', jPanelFeedback, 'hfill', ' ');
        
        % freq filter
        gui_component('Label', jPanelFeedback, 'br', ' ');
        gui_component('label', jPanelFeedback, ' br', 'Frequency Filters:');
        gui_component('label', jPanelFeedback, 'br', 'Highpass: ');
        jTextHighpass = gui_component('texttime', jPanelFeedback, 'tab', ' '); 
        gui_component('label', jPanelFeedback, [], ' Hz');
        gui_component('label', jPanelFeedback, 'br', 'Lowpass: ');
        jTextLowpass = gui_component('texttime', jPanelFeedback, 'tab', ' '); 
        gui_component('label', jPanelFeedback, [], ' Hz');

    jPanelNew.add(jPanelFeedback);
    
    % ===== START BUTTON =====
    jButtonStart = gui_component('button', jPanelNew, [], 'Start Collection', [], [], @StartRealtime_Callback);
   
% Create the BstPanel object that is returned by the function
    % => constructor BstPanel(jHandle, panelName, sControls)
    bstPanelNew = BstPanel(panelName, ...
                           jPanelNew, ...
                           struct('jPanelSubject',          jPanelSubject, ...
                           'jTextCurSubject',               jTextCurSubject, ...
                           'jButtonRegisterSubject',        jButtonRegisterSubject, ...
                           'jButtonAddHeadpoints',          jButtonAddHeadpoints, ...
                           'jPanelFT',                      jPanelFT, ...
                           'jTextFTHost',                   jTextFTHost, ...
                           'jTextFTPort',                   jTextFTPort, ...
                           'jButtonInitFT',                 jButtonInitFT, ...
                           'jPanelOptions',                 jPanelOptions, ...
                           'jTextBlock',                    jTextBlock, ...
                           'jTextHighpass',                 jTextHighpass, ...
                           'jTextLowpass',                  jTextLowpass, ...
                           'jTextMovement',                 jTextMovement, ...
                           'jRadioCortexDisplay',           jRadioCortexDisplay, ...
                           'jRadioOtherDisplay',            jRadioOtherDisplay, ...
                           'jTextFunction',                 jTextFunction, ...
                           'jButtonStart',                  jButtonStart));
                                       
end

%% Set preferences
function SetPreferences(OPTIONS)
    ctrl = bst_get('PanelControls', 'Realtime');
    ctrl.jTextFTHost.setText(OPTIONS.FTHost);
    ctrl.jTextFTPort.setText(num2str(OPTIONS.FTPort));
    ctrl.jTextBlock.setText(num2str(OPTIONS.BlockTime));
    ctrl.jTextMovement.setText(num2str(OPTIONS.HeadMoveThresh));
    ctrl.jTextHighpass.setText(num2str(OPTIONS.HP));
    ctrl.jTextLowpass.setText(num2str(OPTIONS.LP));

end

%% Create template
function RTConfig = GetTemplate()

% Intialize global variable
    RTConfig = struct(...
        'FThost',           [], ...     % fieldtrip buffer host address
        'FTport',           [], ...     % fieldtrip buffer port number
        'Timeout',          4000, ...   % timeout for requests to get data from buffer (ms)
        'ChunkSamples',     [], ...     % number of samples in each data chunk from ACQ
        'nChunks',          0, ...      % number of chunks to collect for each processing block
        'BlockSamples',     0, ...      % minimum number of samples per processing block
        'SampRate',         [], ...     % sampling rate
        'MegRefCoef',       [], ...     % third gradiant coefficients
        'ChannelGains',     [], ...     % channel gains to be applied to buffer data
        'iStim',            [], ...     % indices of stim channels
        'iMeg',             [], ...     % indices of MEG channels
        'iMegRef',          [], ...     % indices of MEG ref channels
        'iHeadLoc',     [], ...     % indices of head localization channels
        'nBlockSmooth',     0, ...      % smoothing (number of buffer chunks);
        'SmoothingFilter',  [], ...     % median filter smoothing for the display (# of blocks) 
        'RefLength',        0, ...      % reference period (seconds)
        'nRefBlocks',       0, ...      % reference period blocks
        'FilterFreq',       [], ...     % highpass freq
        'scoutName',        [], ...     % name of source map scout for processing data
        'ScoutVertices',    [], ...     % Scout vertices for processing
        'fdbkTrialTime',    [], ...     % time of each feedback trial
        'restTrialTime',    [], ...     % time of each rest trial
        'nFeedbackBlocks',  0, ...      % Feedback trial length (blocks)
        'nRestBlocks',      0, ...      % rest trial length (blocks)
        'nTrials',          0, ...      % number of trials
        'Projector',        [], ...     % projector for noise removal
        'HeadPositionRaw',  [], ...     % Initial headposition in device coordinates
        'prevSample',       [], ...     % previous sample read from the FT buffer header
        'refMean',          [], ...     % mean of sources over reference period
        'refStd',           [], ...     % standard deviation of sources over reference period
        'LastMeasures',     [], ...     % previous source maps (length of smoothing filter)
        'hFig',             0, ...      % current figure
        'iDS',              []);        % index of currently loaded dataset
    
end

%% Prepare subject
function RegisterSubject_Callback(h, ev)
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Realtime');
    % Get subject
    SubjectName = char(ctrl.jTextCurSubject.getText());
    [tmp, iSubject] = bst_get('Subject', SubjectName);

    % Check if subject exists
    if ~isempty(iSubject)
        % user can use existing or reset the subject
        res = java_dialog('question', ...
            ['This subject already exists.  You can choose to: ', 10 ...
                '- use the existing anatomy and dataset?',  10 ...
                '- reset the subject and clear out existing anatomy and data?'], ...
            'Register subject', [], {'Existing', 'Reset', 'Cancel'});
        % User canceled operation or will use the existing subject data
        if isempty(res) || strcmpi(res, 'Cancel') || strcmpi(res, 'Existing')
            return
        end
        
        % TODO if existing, be sure all the conditions are created
        
        % Reset the subject (delete subject and create new)
        if strcmpi(res, 'Reset')    
            db_delete_subjects( iSubject )
        end
    end
    
    % ===== Create new subject
    [tmp, iSubject] = db_add_subject(SubjectName, [], 1, 0);
    sTemplate = bst_get('AnatomyDefaults', 'ICBM152');
    db_set_template( iSubject, sTemplate(1), 0 )
    
    % ===== Prepare condition: HeadPoints
    db_add_condition(SubjectName, 'HeadPoints');
        
    % ===== Prepare condition: Noise
    db_add_condition(SubjectName, 'Noise');

    % ===== Prepare condition: RealtimeData
    db_add_condition(SubjectName, 'RealtimeData');
    
    % ===== Prepare condition: CleanSSP
    db_add_condition(SubjectName, 'CleanSSP');

    % Reload subject
    db_reload_subjects(iSubject);
end

%% Add HeadPoints to condition
function AddHeadPoints_Callback(h, ev)
    isWarp = 0;
    % Ask subject if the anatomy will be warped
    res = java_dialog('question', ...
        'Do you want to warp the anatomy to these points?', ...
        'Add Headpoints', [], {'Yes', 'No', 'Cancel'});
    % User cancelled operation
    if isempty(res) || strcmpi(res, 'Cancel')
        return
    end

    % Warp
    if strcmpi(res, 'Yes')    
        isWarp = 1;
    end

    % Get panel controls
    ctrl = bst_get('PanelControls', 'Realtime');
    % Get condition
    [sStudy, iStudy] = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'HeadPoints'));
    
    % Copy default channel file to this condition
    DefChannelFile = bst_fullfile(bst_get('BrainstormHomeDir'), 'defaults', 'meg', 'channel_ctf_default.mat');
    file_copy(DefChannelFile, bst_fileparts(file_fullpath(sStudy.FileName)));
    % Reload condition
    db_reload_studies(iStudy);
    % Get updated study definition
    sStudy = bst_get('Study', iStudy);

    % Get the channel file information
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = in_bst_channel(ChannelFile);
    % find existing headpoints and transformation
    if isempty(ChannelMat.TransfMegLabels) || isempty(ChannelMat.HeadPoints.Loc)
        % Update the channel file with the head points
        LastUsedDirs = bst_get('LastUsedDirs');
        PosFile = java_getfile( 'open', 'Select POS file...', LastUsedDirs.ImportChannel, 'single', 'files', ...
            {{'*.pos'}, 'POS files', 'POLHEMUS'}, 0);
        if isempty(PosFile)
            return;
        end
        % Read POS file
        HeadMat = in_channel_pos(PosFile);
        % Copy head points
        ChannelMat.HeadPoints = HeadMat.HeadPoints;
        % Force re-alignment on the new set of NAS/LPA/RPA (switch from CTF coil-based to SCS anatomical-based coordinate system)
        ChannelMat = channel_detect_type(ChannelMat, 1, 0);
        save(ChannelFile, '-struct', 'ChannelMat');
    end
    
    % Warp, if required
    if isWarp
        % Warp surface for new head points
        % bst_warp_prepare(ChannelFile, Options)
        %    Options     : Structure of the options
        %         |- tolerance    : Percentage of outliers head points, ignored in the calulation of the deformation. 
        %         |                 Set to more than 0 when you know your head points have some outliers.
        %         |                 If not specified: asked to the user (default 
        %         |- isInterp     : If 0, do not do a full interpolation (default: 1)
        %         |- isScaleOnly  : If 1, do not perform the full deformation but only a linear scaling in the three directions (default: 0)
        %         |- isSurfaceOnly: If 1, do not warp/scale the MRI (default: 0)
        %         |- isInteractive: If 0, do not ask anything to the user (default: 1)
        Options.tolerance = 0.02;
        Options.isInterp = [];
        Options.isScaleOnly = 0;
        Options.isSurfaceOnly = 1;
        Options.isInteractive = 1;
        hFig = bst_warp_prepare(ChannelFile, Options);
        % Close figure
        close(hFig);
    end
end

%% Initialize Fieldtrip Buffer
function InitFieldtripBuffer_Callback(h, ev)

    % Get panel controls
    ctrl = bst_get('PanelControls', 'Realtime');
    ft_host = char(ctrl.jTextFTHost.getText());
    ft_port = str2double(char(ctrl.jTextFTPort.getText()));
    InitFieldtripBuffer(ft_host, ft_port);
end

% Also called by bst_headtracking
function hdr = InitFieldtripBuffer(ft_host, ft_port)
    % Initialize FieldTrip
    [isInstalled, errMsg, PlugFt] = bst_plugin('Install', 'fieldtrip');
    if ~isInstalled
        error('FieldTrip plugin required (full version, not lite which Brainstorm would get by default). %s', errMsg);
    end
    ft_dir = bst_fileparts(which(PlugFt.TestFile));
    % Add fieldtrip buffer to path
    ft_rtbuffer = bst_fullfile(ft_dir, 'realtime', 'src', 'buffer', 'matlab');
    ft_io = bst_fullfile(ft_dir, 'fileio');
    if exist(ft_rtbuffer, 'dir') && exist(ft_io, 'dir')
        addpath(ft_rtbuffer);
        addpath(ft_io);
    else
        error('Cannot find the FieldTrip realtime and/or io directories. Full (not lite) version of FieldTrip required.');
    end
    
    %     % Some Fieldtrip versions may require multithreading dll. Depends on how the
    %     % buffer mex file was compiled.
    %     % TODO: can we test if this is needed first?  And check 32/64 bit.
    %     ft_pthreadlib = bst_fullfile(ft_dir, 'realtime', 'src', 'external', 'pthreads-win64', 'lib');
    %     if ispc && ~exist(bst_fullfile(ft_rtbuffer, 'pthreadGC2-w64.dll'), 'file') && ...
    %             exist(bst_fullfile(ft_pthreadlib, 'pthreadGC2-w64.dll'), 'file')
    %         file_copy(bst_fullfile(ft_pthreadlib, 'pthreadGC2-w64.dll'), ...
    %             bst_fullfile(ft_rtbuffer, 'pthreadGC2-w64.dll'));
    %     end
    
    % bst_headtracking used to find and kill "old" matlab processes.
    %     pid = feature('getpid');
    %     [tmp,tasks] = system('tasklist');
    %     pat = '\s+';
    %     str=tasks;
    %     s = regexp(str, pat, 'split');
    %     iMatlab = find(~cellfun(@isempty, strfind(s, 'MATLAB.exe')));
    %
    %     if numel(iMatlab) > 1
    %         disp('Multiple MATLAB processes running. You should verify and probably quit or kill other MATLAB instances.');
    %         %         % kill the extra matlab(s)
    %         %         disp('An old MATLAB process is still running, stopping now...');
    %         %         temp = str2double(s(iMatlab+1));
    %         %         iKill = find(temp ~= pid);
    %         %         for ii=1:length(iKill)
    %         %             [status,result] = system(['Taskkill /PID ' num2str(temp(iKill(ii))) ' /F']);
    %         %             if status
    %         %                 disp(result);
    %         %                 disp('The process could not be stopped.  Please stop it manually');
    %         %             else
    %         %                 disp(result);
    %         %             end
    %         %         end
    %     end
    hdr = [];
    if strcmpi(ft_host, 'localhost')
        % ===== Initialize the buffer
        try
            disp('BST> Initializing FieldTrip buffer...');
            buffer('tcpserver', 'init', ft_host, ft_port);
        catch ME
            disp('BST> Warning: FieldTrip buffer is already initialized.  Resetting.');
            buffer('flush_hdr', [], ft_host, ft_port);
            % To confirm if flush makes nsamples start from 0 again.
            disp(ME);
        end
        
        % ===== Waiting for acquisition to start
        bst_progress('start', 'Waiting for data acquisition to start', ...
            '<HTML>On acquisition system: <BR> 1. Start buffer program <BR> 2. Start CTF Acq and load study <BR> 3. Start acquisition');
        
        % TODO: This loop can make Matlab crash if wait is too long.
        % Wait for buffer to start filling. If filled before (this is not the first
        % time that we run this file in this session without closing matlab), this
        % step will be passed
        while (1)
            try
                % [nsamples, nevents, timeout]
                hdr = buffer('wait_dat', [1, 0, 1000], ft_host, ft_port);
                break;
            catch ME
                pause(1);
                disp(ME); % for debugging
            end
        end
        bst_progress('stop');
        disp('BST> Acquisition started.');
    else
        % Try connecting to the buffer at the specified IP.
        try
            hdr = buffer('get_hdr', [], ft_host, ft_port);
        catch ME
            disp('Unable to get header from buffer at provided IP. \nBuffer should be initialized first. \nA firewall could block access and cause this error.');
            rethrow(ME);
        end
    end
    
end

%% Start Collection
function StartRealtime_Callback(h,ev)
    ctrl = bst_get('PanelControls', 'Realtime');    
    if ctrl.jRadioCortexDisplay.isSelected()
        realtime_demo();
    else
        fxn=char(ctrl.jTextFunction.getText());
        eval(fxn);
    end
end

%% Initialize the measurement parameters
% This is called from realtime_demo or other external function, which must first
% set up RTConfig.
function InitializeRealtimeMeasurement(ReComputeHeadModel)

    global RTConfig
    
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Realtime');
    RTConfig.FThost = char(ctrl.jTextFTHost.getText());
    RTConfig.FTport = str2double(char(ctrl.jTextFTPort.getText()));
    Subject = char(ctrl.jTextCurSubject.getText());
    
    %     % TODO include the path to these files in bst
    %     rtlib_dir = fileparts(which(mfilename));
    %     addpath(fullfile(rtlib_dir, 'dllFiles'));

    bst_progress('start', 'Initialize realtime collection', 'Checking channel information');

    % ===== Channel info
    [RealtimeChannelMat, RTConfig.ChannelGains] = SetupRealtimeChannelFile(Subject, RTConfig.FThost, RTConfig.FTport);
    % noise compensation
    RTConfig.MegRefCoef = RealtimeChannelMat.MegRefCoef;
    % channel indices
    % TODO: this should be selected by type, multiple stim channel possibilities.
    RTConfig.iStim = find(strcmpi({RealtimeChannelMat.Channel.Name},'UPPT001'));     % find the stimulation channel from parallel port
    RTConfig.iMeg = good_channel(RealtimeChannelMat.Channel,[],'MEG');
    RTConfig.iMegRef = good_channel(RealtimeChannelMat.Channel,[],'MEG REF');
    % Head localization channels
    iHeadLoc = find(strcmp({RealtimeChannelMat.Channel.Type}, 'HLU'));
    [Unused, iSortHlu] = sort({RealtimeChannelMat.Channel(iHeadLoc).Name});
    RTConfig.iHeadLoc = iHeadLoc(iSortHlu); % Probably not needed.
    % We don't apply gains to head loc channels (and following).
    RTConfig.ChannelGains(iHeadLoc(1):end) = [];
    
    bst_progress('text', 'Checking data information');
    
    % ===== Define the buffer acquisition blocksize

    hdr = buffer('get_hdr', [], RTConfig.FThost, RTConfig.FTport);
    RTConfig.SampRate = hdr.fsample;
    RTConfig.prevSample = hdr.nsamples;
    RTConfig.ChunkSamples = FindAcquisitionBlockSize(); 
    
    blocktime = str2double(char(ctrl.jTextBlock.getText()))/1000; %ms -> sec
    chnktime = RTConfig.ChunkSamples/RTConfig.SampRate;
    RTConfig.nChunks = round(blocktime/chnktime);
    RTConfig.BlockSamples = RTConfig.ChunkSamples * RTConfig.nChunks;
    
    % ===== Smoothing
    %TODO what is the formula for smoothing?
    if RTConfig.nBlockSmooth > 0
        RTConfig.SmoothingFilter = ones(RTConfig.nBlockSmooth,1)*.2; %[.38 .28 .18 .1 .06]'; 
    end
    
    % ===== Reference period
    % TODO why subtract the number of smoothing blocks?
    RTConfig.nRefBlocks = fix((RTConfig.RefLength*RTConfig.SampRate)/RTConfig.BlockSamples) - length(RTConfig.SmoothingFilter);
    
    % ===== trial info
    if ~isempty(RTConfig.fdbkTrialTime)
        RTConfig.nFeedbackBlocks = fix((RTConfig.fdbkTrialTime*RTConfig.SampRate)/RTConfig.BlockSamples);
        RTConfig.nRestBlocks = fix((RTConfig.restTrialTime*RTConfig.SampRate)/RTConfig.BlockSamples);
    end
    % ===== Freq filtering
    RTConfig.FilterFreq = [str2double(char(ctrl.jTextHighpass.getText())), str2double(char(ctrl.jTextLowpass.getText()))];
    
    % ===== Read SSP projectors 
    [cleanStudy, ~] = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'CleanSSP'));
    if isempty(cleanStudy.Channel)
        RTConfig.Projector = [];
    else
        % TODO uniformize the CleanSSP and RealtimeData channel files
        ChannelMat = in_bst_channel(file_fullpath(cleanStudy.Channel.FileName));
        iProjMEG = good_channel(ChannelMat.Channel,[],'MEG');
        % Build projector matrix
        Projector = process_ssp2('BuildProjector', ChannelMat.Projector, 1);
        % use only the MEG channels
        RTConfig.Projector = Projector(iProjMEG,iProjMEG);
    end
    
    [sStudy, iStudy] = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'RealtimeData'));
    if ReComputeHeadModel || isempty(sStudy.HeadModel)
        % TODO remove existing model and sources
        bst_progress('text', 'Measuring head position and computing imaging kernel');
        % ===== Head localization
        java_dialog('warning',['Localize head on ACQ workstation and then start acquisition. ' 10 10 ...
            'Click OK when done!'],'Head localization');
        RTConfig.HeadPositionRaw = HeadLocalization();
        % ===== Compute Imaging Kernel
        ResultsFile = ComputeImagingKernel();
    else
        [sStudy, iStudy] = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'RealtimeData'));
        [tmp,tmp,iResults] = bst_get('ResultsForDataFile', sStudy.Data(1).FileName, iStudy);
        ResultsFile = sStudy.Result(iResults(end)).FileName;
    end
    
    ResultsMat = in_bst_results(ResultsFile);
    RTConfig.ImagingKernel = ResultsMat.ImagingKernel;
    if ~isempty(RTConfig.scoutName)
        sSurf = in_tess_bst(ResultsMat.SurfaceFile);
        verts=[];
        for ii = 1:length(RTConfig.scoutName)
            iScout = find(strcmpi({sSurf.Atlas(sSurf.iAtlas).Scouts.Label},RTConfig.scoutName{ii}));
            verts = [verts sSurf.Atlas(sSurf.iAtlas).Scouts(iScout).Vertices]; %#ok<AGROW>
        end
        RTConfig.ScoutVertices = verts; % group all scouts together
    end
    
    bst_progress('text', 'Setting up display');
    % ===== Display
    if ctrl.jRadioCortexDisplay.isSelected() || ~isempty(strfind(char(ctrl.jTextFunction.getText()),'demo'))
        % Display sources on cortex surface
        [RTConfig.hFig, RTConfig.iDS, ~] = view_surface_data([], ResultsFile);
        % Get colormap
        sColormap = bst_colormaps('GetColormap','Source');        
        % turn off display of colorbar
        sColormap.DisplayColorbar = 0;        
        % these values are z-scores - display relative
        sColormap.isAbsoluteValues = 0;       
        % colorbar range is [-2,2]
        sColormap.MaxMode  = 'custom';
        sColormap.MinValue = -2;
        sColormap.MaxValue = 2;
        bst_colormaps('SetColormap','Source', sColormap);
        % Fire change notificiation to all figures (3DViz and Topography)
        bst_colormaps('FireColormapChanged','Source');
    end
    
    % ===== Realtime processing
    % Read the header
    hdr = buffer('get_hdr', [], RTConfig.FThost, RTConfig.FTport);
    RTConfig.prevSample = hdr.nsamples;

    bst_progress('stop');
end

%% Setup Realtime Channel File
function [ChannelMat, ChannelGains] = SetupRealtimeChannelFile(Subject, ft_host, ft_port)
    
    [ChannelMat, ChannelGains] = ReadBufferRes4(ft_host, ft_port); 
    
    % Add channel file to condition RealtimeData
    [sStudy, iStudy] = bst_get('StudyWithCondition', fullfile(Subject, 'RealtimeData'));
    if isempty(iStudy)
        bst_error('RealtimeData condition not found. You must first register the subject');
    end
    db_set_channel(iStudy, ChannelMat, 2, 0);
    
    % Create a Small Data File
    % If we don't have a data file in the study, we make a fake one.
    if  isempty(sStudy.Data)
        % Create structure
        dataSt = db_template('datamat');
        dataSt.F        = 1e-12 .* repmat(rand([hdr.nchans,1]), [1 2]);        % Should be filled when we read the data
        dataSt.Comment  = 'RealTimeData'; % Name of data file
        dataSt.ChannelFlag = ones(hdr.nchans,1);
        dataSt.Time     = [0, 1/hdr.fsample];    
        dataSt.DataType = 'recordings';
        dataSt.Device   = 'CTF';
        % Register in database
        db_add(iStudy, dataSt);
    end
    
    % Reload condition
    db_reload_studies(iStudy);
end

%% Read buffer header res4 
function [ChannelMat, ChannelTypes, ChannelGains] = ReadBufferRes4(ft_host, ft_port)
    % Read *.res4 and create channel file
    
    hdr = buffer('get_hdr', [], ft_host, ft_port);
    
    % Get temporary folder
    tmp_dir = bst_get('BrainstormTmpDir');
    % Write .res4 file
    res4_file = fullfile(tmp_dir, 'temp.res4');
    fid = fopen(res4_file, 'w', 'l');
    fwrite(fid, hdr.ctf_res4, 'uint8');
    fclose(fid);
    % Write empty .meg4
    meg4_file = fullfile(tmp_dir, 'temp.meg4');
    fid = fopen(meg4_file, 'w', 'l');
    fclose(fid);
    % Reading structured res4
    % TODO: avoid brainstorm warnings due to "fake" dataset.
    if nargout >= 1
        [ChannelMat, header] = in_channel_ctf(res4_file);
        ChannelGains = double(header.gain_chan);
        ChannelGains(ChannelGains == 0) = 1; % avoid div by 0
    else
        ChannelMat = in_channel_ctf(res4_file);
    end
    
    % Res4 returns info about what is being recorded, not the channels being
    % sent to the buffer.  So we need to filter by channel names. But we also
    % need all MEG channels to display the helmet.
    % Channel file indices of channels present in the buffer
    [Unused, ChannelTypes.iChan] = ismember(hdr.channel_names, {ChannelMat.Channel.Name});
    % Channel file indices of all MEG channels 
    ChannelTypes.iMegFull = good_channel(ChannelMat.Channel,[],'MEG');
    % Channel file indices of MEG channels in the buffer
    ChannelTypes.iMeg = ChannelTypes.iMegFull(ismember(ChannelTypes.iMegFull, ChannelTypes.iChan));
    % Full MegRefCoef matrix indices for MEG channels in the buffer
    [Unused, iMegCoefs] = ismember(ChannelTypes.iMeg, ChannelTypes.iMegFull);
    % Buffer indices for MEG channels
    ChannelTypes.iBufMeg = good_channel(ChannelMat.Channel(ChannelTypes.iChan),[],'MEG');
    % Buffer indices for MEG REF channels
    iBufMegRef = good_channel(ChannelMat.Channel(ChannelTypes.iChan),[],'MEG REF');
    nMegRef = numel(iBufMegRef);
    % For MEG channels, we need all references.
    if ~isempty(ChannelTypes.iMeg) 
        if nMegRef ~= size(ChannelMat.MegRefCoef, 2)
            error('Inconsistent number of MEG reference channels: %d, expecting %d.', ...
                nMegRef, size(ChannelMat.MegRefCoef, 2));
        end
        ChannelMat.MegRefCoef = ChannelMat.MegRefCoef(iMegCoefs, :);
    else
        ChannelMat.MegRefCoef = [];
    end
    if nargout >= 1
        ChannelGains = ChannelGains(ChannelTypes.iChan)';
    end
end

%% Head localization
function HeadPositionRaw = HeadLocalization()
    
    global RTConfig
    % Get panel controls
    ctrl = bst_get('PanelControls', 'Realtime');
    
    % Reading channel coordinates in DEWAR coordinates 
    % (.res4 read from the FieldTrip buffer)
    [sStudy, iStudy] = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'RealtimeData'));
    ChannelMat = in_bst_channel(file_fullpath(sStudy.Channel.FileName));
    
    % Read the last HLC data available from the buffer.
    DataMat = GetBufferData(false, RTConfig.iHeadLoc);    
    % Extract fiducial points and add them to ChannelMat
    hlc = mean(DataMat, 2)/1e6;  % positions should be in "m". um => m
    ChannelMat.SCS.NAS = hlc(1:3)'; % in m
    ChannelMat.SCS.LPA = hlc(4:6)'; % in m
    ChannelMat.SCS.RPA = hlc(7:9)'; % in m
    HeadPositionRaw(1) = sqrt(sum(hlc(1:3).^2));
    HeadPositionRaw(2) = sqrt(sum(hlc(4:6).^2));
    HeadPositionRaw(3) = sqrt(sum(hlc(7:9).^2));

    % Compute transformation (DEWAR => CTF COIL)
    transfSCS = cs_compute(ChannelMat, 'scs'); % NAS, LPA and RPA in m
    ChannelMat.SCS.R = transfSCS.R;
    ChannelMat.SCS.T = transfSCS.T; % in m
    ChannelMat.SCS.Origin = transfSCS.Origin;

    % TRANFORMATION: CTF COIL => ANATOMICAL NAS/LPA/RPA
    % Get the transformation for HPI head coordinates (POS file) to Brainstorm
    HeadPointsStudy = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'HeadPoints'));
    HPChannelFile = file_fullpath(HeadPointsStudy.Channel.FileName);
    HPChannelMat = in_bst_channel(HPChannelFile);
    % find existing headpoints and transformation
    iTrans = find(~cellfun(@isempty,strfind(HPChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF')));
    if isempty(iTrans)
        bst_error('No SCS transformation in the channel file')
        return;
    end
    % Get the translation and rotation from the HeadPoints tranformation
    trans = HPChannelMat.TransfMeg{iTrans};
    anatR = trans(1:3, 1:3);
    anatT = trans(1:3, 4); % in m

    % add the tranformation
    transfAnat = [anatR, anatT; 0 0 0 1]*[transfSCS.R, transfSCS.T; 0 0 0 1]; % in m

    % Update the ChannelMat structure
    ChannelMat.SCS.R = transfAnat(1:3, 1:3);
    ChannelMat.SCS.T = transfAnat(1:3, 4); % in m
    % 
    % Process each sensor
    for i = 1:length(ChannelMat.Channel)
        if ~isempty(ChannelMat.Channel(i).Loc)
            % Converts the electrodes locations
            % ChannelMat.SCS is currently in m
            %ChannelMat.Channel(i).Loc = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.Channel(i).Loc' ./ 1000)' .* 1000;
            ChannelMat.Channel(i).Loc = bst_bsxfun(@plus, ChannelMat.SCS.R * ChannelMat.Channel(i).Loc, ChannelMat.SCS.T);
        end
    end

    % Convert the fiducials positions
%     ChannelMat.SCS.NAS = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.NAS ./ 1000) .* 1000;  %points stored in meters
%     ChannelMat.SCS.LPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.LPA ./ 1000) .* 1000;
%     ChannelMat.SCS.RPA = cs_convert(ChannelMat, 'mri', 'scs', ChannelMat.SCS.RPA ./ 1000) .* 1000;
    ChannelMat.SCS.NAS = bst_bsxfun(@plus, ChannelMat.SCS.R * ChannelMat.SCS.NAS', ChannelMat.SCS.T)';  %points stored in meters
    ChannelMat.SCS.LPA = bst_bsxfun(@plus, ChannelMat.SCS.R * ChannelMat.SCS.LPA', ChannelMat.SCS.T)';
    ChannelMat.SCS.RPA = bst_bsxfun(@plus, ChannelMat.SCS.R * ChannelMat.SCS.RPA', ChannelMat.SCS.T)';
    
    % Update the list of transformation
    if isempty(ChannelMat.TransfMegLabels)
        iTrans = [];
    else
        iTrans = find(~cellfun(@isempty,strfind(ChannelMat.TransfMegLabels, 'Native=>Brainstorm/CTF')));
    end

    if isempty(iTrans)
        ChannelMat.TransfMeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
        ChannelMat.TransfMegLabels{end+1} = 'Native=>Brainstorm/CTF';
        ChannelMat.TransfEeg{end+1} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
        ChannelMat.TransfEegLabels{end+1} = 'Native=>Brainstorm/CTF';
    else
        ChannelMat.TransfMeg{iTrans} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
        ChannelMat.TransfMegLabels{iTrans} = 'Native=>Brainstorm/CTF';
        ChannelMat.TransfEeg{iTrans} = [ChannelMat.SCS.R, ChannelMat.SCS.T; 0 0 0 1];
        ChannelMat.TransfEegLabels{iTrans} = 'Native=>Brainstorm/CTF';
    end

    % Save new channel file to the target studies
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    save(ChannelFile, '-struct', 'ChannelMat')
    % Reload this condition
    db_reload_studies(iStudy);

    % Quality control for subject position
    sSubject = bst_get('Subject');
    hFig = view_surface(sSubject.Surface(sSubject.iScalp).FileName);
    % Set view from the left
    figure_3d('SetStandardView', hFig, 'left');
    figure_3d('ViewAxis', hFig, 1);
    view_helmet(ChannelFile, hFig);
    pause(5);
    close(hFig);
end

%% Compute imaging kernel
function ResultsFile = ComputeImagingKernel()
    ctrl = bst_get('PanelControls', 'Realtime');

    % ===== Noise Covariance
    [sStudy, iRealTimestudy] = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'RealtimeData'));
    if isempty(sStudy.NoiseCov) % if the study does not have a noise cov, get one
        [NoiseCovStudy, iNoiseCovStudy] = bst_get('StudyWithCondition', fullfile(char(ctrl.jTextCurSubject.getText()), 'Noise'));

        if isempty(NoiseCovStudy) % if there is no emptyroom study, use the default
            bst_error('There is no Noise study available for the noise covariance.  You must first register your subject');
        end

        % find the noise cov in this study
        NoiseCovFile = NoiseCovStudy.NoiseCov;
        if isempty(NoiseCovFile)
            iDatas = bst_get('DataForDataList',iNoiseCovStudy, 'Raw');
            NoiseCovMat = load(bst_noisecov(iNoiseCovStudy, [], iDatas));
            import_noisecov(iNoiseCovStudy, NoiseCovMat, 1);
        end

        % copy the Noise cov from the noise study to the realtime study
        db_set_noisecov(iNoiseCovStudy, iRealTimestudy);
    end

    % ===== Computation of Head Model: OVERLAPPING SPHERES
    [sStudy, ~] = bst_get('Study', iRealTimestudy);
    InputFiles = {sStudy.Data(1).FileName};
    % Process: Compute head model
    bst_process('CallProcess', 'process_headmodel', ...
        InputFiles, [], ...
        'comment', '', ...
        'sourcespace', 1, ...
        'meg', 3, ...  % Overlapping spheres
        'eeg', 1, ...  % 
        'ecog', 1, ...  % 
        'seeg', 1, ...
        'openmeeg', struct(...
             'BemFiles', {{}}, ...
             'BemNames', {{'Scalp', 'Skull', 'Brain'}}, ...
             'BemCond', [1, 0.0125, 1], ...
             'BemSelect', [1, 1, 1], ...
             'isAdjoint', 0, ...
             'isAdaptative', 1, ...
             'isSplit', 0, ...
             'SplitLength', 4000));

    % ===== Source Estimation 
    % Process: Compute sources
    sFile = bst_process('CallProcess', 'process_inverse', InputFiles, [], ...
    'comment', '', ...
    'method', 1, ...  % Minimum norm estimates (wMNE)
    'wmne', struct(...
         'SourceOrient', {{'fixed'}}, ...
         'loose', 0.2, ...
         'SNR', 3, ...
         'pca', 1, ...
         'diagnoise', 0, ...
         'regnoise', 1, ...
         'magreg', 0.1, ...
         'gradreg', 0.1, ...
         'eegreg', 0.1, ...
         'depth', 1, ...
         'weightexp', 0.5, ...
         'weightlimit', 10), ...
    'sensortypes', 'MEG', ...
    'output', 1);  % Kernel only: shared

    ResultsFile = sFile(1).FileName;
end

%% Get block size sent by acquisition system into buffer
function AcqBlockSamples = FindAcquisitionBlockSize()
    global RTConfig
    hdr = buffer('wait_dat', [1, 0, RTConfig.Timeout], RTConfig.FThost, RTConfig.FTport);
    prevSample = hdr.nsamples;
    % wait for at least one more sample 
    hdr = buffer('wait_dat', [hdr.nsamples, 0, RTConfig.Timeout], RTConfig.FThost, RTConfig.FTport); % nsamples-1+1
    AcqBlockSamples = hdr.nsamples - prevSample;
end

%% Get data from buffer
function DataMat = GetBufferData(isNextBlock, iChan)
    % isNextBlock = true means get the next block not yet read, not skipping any
    % data and waiting if necessary (default).  false means just get the last
    % block received in the buffer, so it can overlap with the previously read
    % block or there might have been other data since the previously read block
    % that is being skipped.
    
    if nargin < 2
        iChan = [];
    end
    if nargin < 1
        isNextBlock = true;
    end
    global RTConfig

    % Check that RTConfig was previously initialized.
    if isempty(RTConfig) || ~isfield(RTConfig, 'BlockSamples')
        error('RTConfig not initialized before asking for data block.');
    end
    
    % Get data from the buffer
    if isNextBlock
        if isempty(RTConfig.prevSample) || RTConfig.prevSample <= 0
            error('RTConfig.prevSample not set before asking for next data block.');
        end
        hdr = buffer('wait_dat', [RTConfig.prevSample + RTConfig.BlockSamples, 0, RTConfig.Timeout], RTConfig.FThost, RTConfig.FTport);
        % see whether new samples are available
        if (hdr.nsamples - RTConfig.prevSample) >= RTConfig.BlockSamples
            % read data segment from buffer
            dat = buffer('get_dat', RTConfig.prevSample - 1 + [1, RTConfig.BlockSamples], RTConfig.FThost, RTConfig.FTport);
            % remember up to where the data was read
            RTConfig.prevSample = RTConfig.prevSample + RTConfig.BlockSamples;
        else
            dat = [];
        end
    else
        % determine number of samples available in buffer. Wait until at least 1 block available.
        hdr = buffer('wait_dat', [RTConfig.BlockSamples, 0, RTConfig.Timeout], RTConfig.FThost, RTConfig.FTport);
        if hdr.nsamples >= RTConfig.BlockSamples
            % read data segment from buffer
            dat = buffer('get_dat', hdr.nsamples - [RTConfig.BlockSamples, 1], RTConfig.FThost, RTConfig.FTport);
            % remember up to where the data was read
            RTConfig.prevSample = hdr.nsamples;
        else
            dat = [];
        end
    end
    if isempty(dat)
        warning('Timeout waiting for next data block.');
        DataMat = [];
    elseif ~isempty(iChan)
        % TODO: apply gains and 3rd gradient to MEG channels.
        DataMat = double(dat.buf(iChan,:));
    else
        DataMat = double(dat.buf);
    end
end
% function dat = GetNextDataBuffer()
% 
%     global RTConfig
%     % Get data from the buffer
%     waitBuffer = 1;
%     startTime = clock;
%     elapsedTime = 0;
%     dat = [];
%     prevSample = RTConfig.prevSample;
% 
%     while waitBuffer && elapsedTime < 4
%       % determine number of samples available in buffer
%       hdr = buffer('get_hdr', [], RTConfig.FThost,RTConfig.FTport);
% 
%       % see whether new samples are available
%       newsamples = (hdr.nsamples-prevSample);
% 
%       if newsamples>=RTConfig.BlockSamples
% 
%         % determine the samples to process
%         begsample  = prevSample+1;
%         endsample = prevSample + RTConfig.BlockSamples;
% 
%         % remember up to where the data was read
%         RTConfig.prevSample  = endsample;
% 
%         % read data segment from buffer
%         dat = buffer('get_dat',[begsample-1 endsample-1],RTConfig.FThost,RTConfig.FTport);
%         dat = dat.buf;
%         % Exit with the new buffer
%         waitBuffer = 0;    
%       end 
%       elapsedTime = etime(clock, startTime);
%     end
%     
%     if isempty(dat)
%         return; 
%     end
%     dat = double(dat);
%     % DATA PREPROCESSING
%     % Apply gains
%     dat(1:length(RTConfig.ChannelGains),:) = bst_bsxfun(@rdivide, dat(1:length(RTConfig.ChannelGains),:), RTConfig.ChannelGains);
%     % Apply 3rd order gradient
%     Cmegdat = dat(RTConfig.iMeg,:) - RTConfig.MegRefCoef*dat(RTConfig.iMegRef,:);  % Clean MEG data
%     % Remove baseline
%     Cmegdat = Cmegdat - repmat(mean(Cmegdat,2),1,RTConfig.BlockSamples);
%     % Apply EOG and ECG SSP projectors 
%     if ~isempty(RTConfig.Projector)
%         Cmegdat = RTConfig.Projector * Cmegdat;
%     end
%     dat(RTConfig.iMeg,:) = Cmegdat;
% end

%% HEAD TRACKING AND DELAY ESTIMATION (under construction)
function CheckHeadMovement()

    BlockTimeLength = RTConfig.BlockSamples/RTConfig.SampRate;
    if mod(count, fix(10/BlockTimeLength))==0       % check movement every 10 seconds
%         % Delay Estimation
%         hdr = buffer('get_hdr', [], RTConfig.FThost, RTConfig.FTport);
%         delayOfProc = (hdr.nsamples - RTConfig.prevSample)/RTConfig.SampRate;
%         if delayOfProc >= 5    % 2 Sec
%             disp('Recording stopped because of delay')
%             disp(['Delay is: ',num2str(delayOfProc)])
%             break;
%         end
        % Head Tracking
        buf = mean(dat(iHL,:), 2);
        if ~fstTime
            movIndx = max(abs(buf - lastbuf));
            if movIndx > HdThr*1e4 &&  movIndx < EstImgKerThr*1e4   % unit of measurement is um
                disp(['Subject moves her/his head (more than ',num2str(HdThr),'cm)'])
            elseif movIndx > EstImgKerThr*1e4 && realexperimentInd
                button = questdlg(['Subject moves her/his head (more than ',num2str(EstImgKerThr),...
                    'cm)','. Do you want to Re-estimate the kernel?','Restart Recording']);
                if button(1) == 'Y'
                    %                 disp(['Subject moves her/his head (more than ',num2str(EstImgKerThr),'cm)'])
                    disp('Realtime Processing stopped because of movement')
                    count = 0;
                    % Send a pulse to LPT2 as stim --> Stop data recording
                    if SendTriggers
                        io64(ioObj,LPT2,StopTrig);
                        WaitSecs(3/RealtimeConfig.sRate);
                        io64(ioObj,LPT2,0);
                    end
                    % Head Localization
                    rt_head_localization(ChannelMat,iHL,RealtimeConfig.SubjectName,RealtimeConfig.ConditionRealtime)
                    % Source estimation
                    disp('Re estimation of Sources...')
                    ResultsFile = rt_compute_sources();
                    if UseCortexDisplay
                        [hFig, iDS, ~] = view_surface_data([], ResultsFile);
                    end
                    % Restart data recording Recording
                    disp(['Measurement Restart: ' datestr(now)]);
                    % Send a pulse to LPT2 as stim --> Restart data recording
                    if SendTriggers
                        io64(ioObj,LPT2,RefStartTrig);
                        WaitSecs(3/RTConfig.sRate);
                        io64(ioObj,LPT2,0);
                    end
                end
                % Start reading the data
                hdr = buffer('get_hdr', [], RTConfig.FThost, RTConfig.FTport);
                prevSample = hdr.nsamples;
            end
        else
            fstTime = 0;
        end
        lastbuf = buf;
    end
end



