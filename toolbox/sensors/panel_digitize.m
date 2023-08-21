function varargout = panel_digitize(varargin)
% PANEL_DIGITIZE: Digitize EEG sensors and head shape.
% 
% USAGE:             panel_digitize('Start')
%                    panel_digitize('CreateSerialConnection')
%                    panel_digitize('ResetDataCollection')
%      bstPanelNew = panel_digitize('CreatePanel')
%                    panel_digitize('SetSimulate', isSimulate)   Run this from command window after opening the Digitize panel.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
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
% Authors: Elizabeth Bock & Francois Tadel, 2012-2017

eval(macro_method);
end


%% ========================================================================
%  ======= INITIALIZE =====================================================
%  ========================================================================
% Pragma to include the classes used by serial.m: DO NOT REMOVE
%#function serial
%#function icinterface

%% ===== START =====
function Start() 
    global Digitize;
    % ===== PREPARE DATABASE =====
    % If no protocol: exit
    if (bst_get('iProtocol') <= 0)
        bst_error('Please create a protocol first.', 'Digitize', 0);
        return;
    end
    % Get subject
    SubjectName = 'Digitize';
    [sSubject, iSubject] = bst_get('Subject', SubjectName);
    % Create if subject doesnt exist
    if isempty(iSubject)
        % Default anat / one channel file per subject
        UseDefaultAnat = 1;
        UseDefaultChannel = 0;
        [sSubject, iSubject] = db_add_subject(SubjectName, iSubject, UseDefaultAnat, UseDefaultChannel);
        % Update tree
        panel_protocols('UpdateTree');
    end
    
    % ===== PATIENT ID =====
    % Ask for subject id
    PatientId = java_dialog('input', 'Please, enter subject id:', 'Digitize', []);
    if isempty(PatientId)
        return;
    end
    
    % ===== INITIALIZE CONNECTION =====
    % Intialize global variable
    Digitize = struct(...
        'Options',          bst_get('DigitizeOptions'), ...
        'SerialConnection', [], ...
        'Mode',             0, ...
        'hFig',             [], ...
        'iDS',              [], ...
        'SubjectName',      SubjectName, ...
        'ConditionName',    [], ...
        'iStudy',           [], ...
        'PatientID',        PatientId, ...
        'BeepWav',          [], ...
        'Points',           struct(...
            'Label',     [], ...
            'Type',      [], ...
            'Loc',       []), ...
        'iPoint',           0, ...
        'Transf',        []);
%         'FidSets',          2, ...
%         'EEGlabels',        [], ...
%             'nasion',   [], ...
%             'LPA',      [], ...
%             'RPA',      [], ...
%             'hpiN',     [], ...
%             'hpiL',     [], ...
%             'hpiR',     [], ...

    % Start Serial Connection
    if ~CreateSerialConnection()
        return;
    end
    
    % ===== CREATE CONDITION =====
    % Get current date/time
    c = clock;
    % Condition name: PatientId_Date_Run
    for i = 1:99
        % Generate new condition name
        Digitize.ConditionName = sprintf('%s_%02d%02d%02d_%02d', Digitize.Options.PatientId, c(1), c(2), c(3), i);
        % Get condition
        sStudy = bst_get('StudyWithCondition', [SubjectName '/' Digitize.ConditionName]);
        % If condition doesn't exist: ok, keep this one
        if isempty(sStudy)
            break;
        end
    end
    % Create condition
    Digitize.iStudy = db_add_condition(SubjectName, Digitize.ConditionName);
    sStudy = bst_get('Study', Digitize.iStudy);
    % Create an empty channel file in there
    ChannelMat = db_template('channelmat');
    ChannelMat.Comment = Digitize.ConditionName;
    % Save new channel file
    ChannelFile = bst_fullfile(bst_fileparts(file_fullpath(sStudy.FileName)), ['channel_' Digitize.ConditionName '.mat']);
%     save(ChannelFile, '-struct', 'ChannelMat');
    bst_save(ChannelFile, ChannelMat, 'v7');
    % Reload condition (why?)
    db_reload_studies(Digitize.iStudy);

    % ===== DISPLAY DIGITIZE WINDOW =====
    % Display panel
    panelContainer = gui_show('panel_digitize', 'JavaWindow', 'Digitize', [], [], [], []);
    % Hide Brainstorm window
    jBstFrame = bst_get('BstFrame');
    jBstFrame.setVisible(0);
    % Set the window to the left of the screen
    % TODO: fix window width?
    drawnow;
    loc = panelContainer.handle{1}.getLocation();
    loc.x = 0;
    panelContainer.handle{1}.setLocation(loc);
    
    % Load beep sound
    if bst_iscompiled()
        wavfile = bst_fullfile(bst_get('BrainstormHomeDir'), 'toolbox', 'sensors', 'private', 'bst_beep_wav.mat');
        filemat = load(wavfile, 'wav');
        Digitize.BeepWav = filemat.wav;
    end

    % Reset collection
    ResetDataCollection();    
end


%% ========================================================================
%  ======= PANEL FUNCTIONS ================================================
%  ========================================================================

%% ===== CREATE PANEL =====
function [bstPanelNew, panelName] = CreatePanel() 
    % Constants
    panelName = 'Digitize';
    % Java initializations
    import java.awt.*;
    import javax.swing.*;
    import java.awt.event.KeyEvent;
    import org.brainstorm.list.*;
    import org.brainstorm.icon.*;
    % Create new panel
    jPanelNew = gui_component('Panel');
    % Font size for the lists
    largeFontSize = round(20 * bst_get('InterfaceScaling') / 100);
    fontSize      = round(11 * bst_get('InterfaceScaling') / 100);
    
    % ===== MENU BAR =====
    jMenuBar = java_create('javax.swing.JMenuBar');
    jPanelNew.add(jMenuBar, BorderLayout.NORTH);
    % File menu
    jMenu = gui_component('Menu', jMenuBar, [], 'File', [], [], [], []);
    gui_component('MenuItem', jMenu, [], 'Start over', IconLoader.ICON_RELOAD, [], @(h,ev)bst_call(@ResetDataCollection, 1), []);
    gui_component('MenuItem', jMenu, [], 'Edit settings...',    IconLoader.ICON_EDIT, [], @(h,ev)bst_call(@EditSettings), []);
    gui_component('MenuItem', jMenu, [], 'Reset serial connection', IconLoader.ICON_FLIP, [], @(h,ev)bst_call(@CreateSerialConnection), []);
    jMenu.addSeparator();
    jMenu.addSeparator();
    gui_component('MenuItem', jMenu, [], 'Save as...', IconLoader.ICON_SAVE, [], @(h,ev)bst_call(@Save_Callback), []);
    if exist('bst_headtracking', 'file')
        gui_component('MenuItem', jMenu, [], 'Start head tracking',     IconLoader.ICON_ALIGN_CHANNELS, [], @(h,ev)bst_call(@(h,ev)bst_headtracking([],1,1)), []);
        jMenu.addSeparator();
    end
    gui_component('MenuItem', jMenu, [], 'Save in database and exit', IconLoader.ICON_RESET, [], @(h,ev)bst_call(@Close_Callback), []);
    % EEG Montage menu
    jMenuEeg = gui_component('Menu', jMenuBar, [], 'EEG montage', [], [], [], []);    
    CreateMontageMenu(jMenuEeg);
    
    % ===== Control Panel =====
    jPanelControl = java_create('javax.swing.JPanel');
    jPanelControl.setLayout(BoxLayout(jPanelControl, BoxLayout.Y_AXIS));
    jPanelControl.setBorder(BorderFactory.createEmptyBorder(7,7,7,7));
    modeButtonGroup = javax.swing.ButtonGroup();
           
%     % ===== Coils panel =====
%     jPanelCoils = gui_river([5,4], [10,10,10,10], 'Head Localization Coils');
%         % Fiducials
%         jButtonhpiN = gui_component('toggle', jPanelCoils, [], 'HPI-N', {modeButtonGroup}, 'Center Coil',    @(h,ev)SwitchToNewMode(1), largeFontSize);
%         jButtonhpiL = gui_component('toggle', jPanelCoils, [], 'HPI-L',   {modeButtonGroup}, 'Left Coil',  @(h,ev)SwitchToNewMode(2), largeFontSize);
%         jButtonhpiR = gui_component('toggle', jPanelCoils, [], 'HPI-R',  {modeButtonGroup}, 'Right Coil', @(h,ev)SwitchToNewMode(3), largeFontSize);
%         % Set size
%         initButtonSize = jButtonhpiR.getPreferredSize();
%         newButtonSize = Dimension(initButtonSize.getWidth(), initButtonSize.getHeight()*1.5);
%         jButtonhpiN.setPreferredSize(newButtonSize);
%         jButtonhpiL.setPreferredSize(newButtonSize);
%         jButtonhpiR.setPreferredSize(newButtonSize);
%         % Non-selectable
%         jButtonhpiN.setFocusable(0);
%         jButtonhpiL.setFocusable(0);
%         jButtonhpiR.setFocusable(0);
%         % Message label
%         jLabelCoilMessage = gui_component('label', jPanelCoils, 'br', '');
%         jLabelCoilMessage.setForeground(Color.red);
%     jPanelControl.add(jPanelCoils);
%     jPanelControl.add(Box.createVerticalStrut(20));
%     
%     % ===== Fiducials panel =====
%     jPanelHeadCoord = gui_river([5,4], [10,10,10,10], 'Anatomical fiducials');
%         % Fiducials
%         jButtonNasion = gui_component('toggle', jPanelHeadCoord, [], 'Nasion', {modeButtonGroup}, 'Nasion',    @(h,ev)SwitchToNewMode(4), largeFontSize);
%         jButtonLPA    = gui_component('toggle', jPanelHeadCoord, [], 'LPA',   {modeButtonGroup}, 'Left Ear',  @(h,ev)SwitchToNewMode(5), largeFontSize);
%         jButtonRPA    = gui_component('toggle', jPanelHeadCoord, [], 'RPA',  {modeButtonGroup}, 'Right Ear', @(h,ev)SwitchToNewMode(6), largeFontSize);
%         % Set size
%         initButtonSize = jButtonNasion.getPreferredSize();
%         newButtonSize = Dimension(initButtonSize.getWidth(), initButtonSize.getHeight()*1.5);
%         jButtonNasion.setPreferredSize(newButtonSize);
%         jButtonLPA.setPreferredSize(newButtonSize);
%         jButtonRPA.setPreferredSize(newButtonSize);
%         % Non-selectable
%         jButtonNasion.setFocusable(0);
%         jButtonLPA.setFocusable(0);
%         jButtonRPA.setFocusable(0);
%         % Message label
%         jLabelFidMessage = gui_component('label', jPanelHeadCoord, 'br', '');
%         jLabelFidMessage.setForeground(Color.red);
%     jPanelControl.add(jPanelHeadCoord);
%     jPanelControl.add(Box.createVerticalStrut(20));
 
    % ===== Fiducials panel =====
    jPanelHeadCoord = gui_river([5,4], [10,10,10,10], 'Fiducials: anatomy & head position');
        % Start fids coord collection
        jButtonFids = gui_component('toggle', jPanelHeadCoord, [], 'Fiducials', {modeButtonGroup}, 'Start/Restart fiducial digitization', @(h,ev)SwitchToNewMode(1), largeFontSize);
        initButtonSize = jButtonFids.getPreferredSize();
        newButtonSize = Dimension(initButtonSize.getWidth()*1.5, initButtonSize.getHeight()*1.5);
        jButtonFids.setPreferredSize(newButtonSize);
        jButtonFids.setFocusable(0);
        % Message label
        jLabelFidMessage = gui_component('label', jPanelHeadCoord, 'br', '');
        jLabelFidMessage.setForeground(Color.red);
    jPanelControl.add(jPanelHeadCoord);
    jPanelControl.add(Box.createVerticalStrut(20));
    
    % ===== EEG panel =====
    jPanelEEG = gui_river([5,4], [10,10,10,10], 'EEG electrodes coordinates');
        % Start EEG coord collection
        jButtonEEGStart = gui_component('toggle', jPanelEEG, [], 'EEG', {modeButtonGroup}, 'Start/Restart EEG digitization', @(h,ev)SwitchToNewMode(7), largeFontSize);
        newButtonSize = Dimension(initButtonSize.getWidth()*1.5, initButtonSize.getHeight()*1.5);
        jButtonEEGStart.setPreferredSize(newButtonSize);
        jButtonEEGStart.setFocusable(0);
        % Separator
        gui_component('label', jPanelEEG, 'hfill', '');
        % Number
        jTextFieldEEG = gui_component('text',jPanelEEG, [], '1', [], 'EEG Sensor # to be digitized', @EEGChangePoint_Callback, largeFontSize);
        jTextFieldEEG.setPreferredSize(newButtonSize)
        jTextFieldEEG.setColumns(3); 
    jPanelControl.add(jPanelEEG);
    jPanelControl.add(Box.createVerticalStrut(20));
    
    % ===== Extra points panel =====
    jPanelExtra = gui_river([5,4], [10,10,10,10], 'Head shape coordinates');
        % Start Extra coord collection
        jButtonExtraStart = gui_component('toggle',jPanelExtra, [], 'Shape', {modeButtonGroup}, 'Start/Restart head shape digitization', @(h,ev)SwitchToNewMode(8), largeFontSize);
        jButtonExtraStart.setPreferredSize(newButtonSize);
        jButtonExtraStart.setFocusable(0);
        % Separator
        gui_component('label', jPanelExtra, 'hfill', '');
        % Number
        jTextFieldExtra = gui_component('text',jPanelExtra, [], '1',[], 'Head shape point to be digitized', @ExtraChangePoint_Callback, largeFontSize);
        jTextFieldExtra.setPreferredSize(newButtonSize)
        jTextFieldExtra.setColumns(3);                        
    jPanelControl.add(jPanelExtra);
    jPanelControl.add(Box.createVerticalStrut(20));
    
    % ===== Extra buttons =====
    jPanelMisc = gui_river([5,4], [2,4,4,0]);
        gui_component('button', jPanelMisc, [], 'Collect point', [], [], @ManualCollect_Callback);
        % Until initial fids are collected and figure displayed, "delete" button is used to "restart".
        %jButtonDeletePoint = gui_component('button', jPanelMisc, 'hfill', 'Delete last point', [], [], @DeletePoint_Callback);
        jButtonDeletePoint = gui_component('button', jPanelMisc, 'hfill', 'Start over', [], [], @ResetDataCollection);
        gui_component('Button', jPanelMisc, [], 'Save as...', [], [], @Save_Callback);
    jPanelControl.add(jPanelMisc);
    jPanelControl.add(Box.createVerticalStrut(20));
    jPanelNew.add(jPanelControl, BorderLayout.WEST);
                               
    % ===== Coordinate Display Panel =====
    jPanelDisplay = gui_component('Panel');
    jPanelDisplay.setBorder(java_scaled('titledborder', 'Coordinates (cm)'));
        % List of coordinates
        jListCoord = JList(largeFontSize);
        jListCoord.setCellRenderer(BstStringListRenderer(fontSize));
        % Size
        jPanelScrollList = JScrollPane();
        jPanelScrollList.getLayout.getViewport.setView(jListCoord);
        jPanelScrollList.setHorizontalScrollBarPolicy(jPanelScrollList.HORIZONTAL_SCROLLBAR_NEVER);
        jPanelScrollList.setVerticalScrollBarPolicy(jPanelScrollList.VERTICAL_SCROLLBAR_ALWAYS);
        jPanelScrollList.setBorder(BorderFactory.createEmptyBorder(10,10,10,10));
        jPanelDisplay.add(jPanelScrollList, BorderLayout.CENTER);
    jPanelNew.add(jPanelDisplay, BorderLayout.CENTER);

    % create the controls structure
    ctrl = struct('jMenuEeg',              jMenuEeg, ...
                  'jButtonFids',           jButtonFids, ...
                  'jLabelFidMessage',      jLabelFidMessage, ...
                  'jListCoord',            jListCoord, ...
                  'jButtonEEGStart',       jButtonEEGStart, ...
                  'jTextFieldEEG',         jTextFieldEEG, ...
                  'jButtonExtraStart',     jButtonExtraStart, ...
                  'jTextFieldExtra',       jTextFieldExtra, ...
                  'jButtonDeletePoint',    jButtonDeletePoint);
%                   'jLabelCoilMessage',     jLabelCoilMessage, ...
%                   'jButtonhpiN',           jButtonhpiN, ...
%                   'jButtonhpiL',           jButtonhpiL, ...
%                   'jButtonhpiR',           jButtonhpiR, ...
%                   'jButtonNasion',         jButtonNasion, ...
%                   'jButtonLPA',            jButtonLPA, ...
%                   'jButtonRPA',            jButtonRPA, ...
    bstPanelNew = BstPanel(panelName, jPanelNew, ctrl);
end


%% ===== CLOSE =====
function Close_Callback()
    % TODO: close serial connection to avoid further callbacks if stylus is pressed.
    gui_hide('Digitize');
end

%% ===== HIDING CALLBACK =====
function isAccepted = PanelHidingCallback() 
    global Digitize;
    % If Brainstorm window was hidden before showing the Digitizer
    if bst_get('isGUI')
        % Get Brainstorm frame
        jBstFrame = bst_get('BstFrame');
        % Hide Brainstorm window
        jBstFrame.setVisible(1);
    end
    % Get study
    [sStudy, iStudy] = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    % If nothing was clicked: delete the condition that was just created
    if isempty(Digitize.Transf)
        % Delete study
        if ~isempty(iStudy)
            db_delete_studies(iStudy);
            panel_protocols('UpdateTree');
        end
    % Else: reload to get access to the EEG type of sensors
    else
        db_reload_studies(iStudy);
    end
    % Unload everything
    bst_memory('UnloadAll', 'Forced');
    isAccepted = 1;
end


%% ===== EDIT SETTINGS =====
function isOk = EditSettings()
    global Digitize
    %Digitize.Options = bst_get('DigitizeOptions');
    isOk = 0;
% TODO: don't think this is needed, delete if ok without    
%     if isempty(Digitize.Options.Fids)
%         Digitize.Options.Fids = 'NAS, LPA, RPA';
%     end
    % Ask for new options
    if isfield(Digitize.Options, 'Fids') && iscell(Digitize.Options.Fids)
        FidsString = sprintf('%s, ', Digitize.Options.Fids{:});
        FidsString(end-1:end) = '';
    else
        FidsString = 'NAS, LPA, RPA';
    end
%              '<HTML><BR><B>Collection settings</B><BR><BR>Digitize MEG HPI coils (0=no, 1=yes):', ...
    [res, isCancel] = java_dialog('input', ...
            {'<HTML><B>Serial connection settings</B><BR><BR>Serial port name (COM1):', ...
             'Unit Type (Fastrak or Patriot):', ...
             '<HTML><BR><B>Collection settings</B><BR><BR>List anatomy and MEG fiducials, in desired order<BR>(NAS, LPA, RPA, HPI-N, HPI-L, HPI-R, HPI-X):', ...
             '<HTML>How many times do you want to collect<BR>the fiducials at the start', ...
             'Beep when collecting point (0=no, 1=yes):'}, ...
            'Digitizer configuration', [], ...
            {Digitize.Options.ComPort, ...
             Digitize.Options.UnitType, ...
             FidsString, ...
             num2str(Digitize.Options.nFidSets), ...
             num2str(Digitize.Options.isBeep)});         
    if isempty(res) || isCancel
        return
    end
    % Check values
    % ~ismember(str2double(res{3}), [0 1])
    if (length(res) < 5) || isempty(res{1}) || isempty(res{2}) || isempty(res{3}) || isnan(str2double(res{4})) || ~ismember(str2double(res{5}), [0 1])
        bst_error('Invalid values.', 'Digitize', 0);
        return;
    end
    % Get entered values
    Digitize.Options.ComPort  = res{1};
    Digitize.Options.UnitType = lower(res{2});
%     Digitize.Options.isMEG        = str2double(res{3});
    Digitize.Options.nFidSets = str2double(res{4});
    Digitize.Options.isBeep   = str2double(res{5});
    % Parse and validate fiducials.
    Digitize.Options.Fids     = str_split(res{3}, '()[],; ', true); % remove empty
    if isempty(Digitize.Options.Fids)
        bst_error('At least 3 anatomy fiducials are required.', 'Digitize', 0);
        return;
    end
    for iFid = 1:numel(Digitize.Options.Fids)
        switch lower(Digitize.Options.Fids{iFid})
            % possible names copied from channel_detect_type
            case {'nas', 'nasion', 'nz', 'fidnas', 'fidnz', 'n', 'na'}
                Digitize.Options.Fids{iFid} = 'NAS';
            case {'lpa', 'pal', 'og', 'left', 'fidt9', 'leftear', 'l'}
                Digitize.Options.Fids{iFid} = 'LPA';
            case {'rpa', 'par', 'od', 'right', 'fidt10', 'rightear', 'r'}
                Digitize.Options.Fids{iFid} = 'RPA';
            otherwise
                if ~strfind(lower(Digitize.Options.Fids{iFid}), 'hpi')
                    bst_error(sprintf('Unrecognized fiducial: %s', Digitize.Options.Fids{iFid}), 'Digitize', 0);
                    return;
                end
                Digitize.Options.Fids{iFid} = upper(Digitize.Options.Fids{iFid});
        end
    end

    if strcmp(Digitize.Options.UnitType,'fastrak')
        Digitize.Options.ComRate = 9600;
        Digitize.Options.ComByteCount = 94;
    elseif strcmp(Digitize.Options.UnitType,'patriot')
        Digitize.Options.ComRate = 115200;
        Digitize.Options.ComByteCount = 120;
    else
        bst_error('Incorrect unit type.', 'Digitize', 0);
        return;
    end
    
    % Save values
    bst_set('DigitizeOptions', Digitize.Options);
    isOk = 1;
end


%% ===== SET SIMULATION MODE =====
% USAGE:  panel_digitize('SetSimulate', isSimulate)
% Run this from command line after opening the Digitize panel.
function SetSimulate(isSimulate) 
    global Digitize
    % Change value
    Digitize.Options.isSimulate = isSimulate;
end


%% ========================================================================
%  ======= ACQUISITION FUNCTIONS ==========================================
%  ========================================================================

%% ===== RESET DATA COLLECTION =====
function ResetDataCollection(isResetSerial)
    global Digitize
    bst_progress('start', 'Digitize', 'Initializing...');
    % Reset serial?
    if (nargin == 1) && isequal(isResetSerial, 1)
        CreateSerialConnection();
    end
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Reset points structure
    Digitize.Points = struct(...
            'Label',     [], ...
            'Type',      [], ...
            'Loc',       []);
    Digitize.Transf = [];
%         'nasion',    [], ...
%         'LPA',       [], ...
%         'RPA',       [], ...
%         'hpiN',     [], ...
%         'hpiL',     [], ...
%         'hpiR',     [], ...
    % Reset counters
    if ~isempty(ctrl)
        ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(1)));
        ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(1)));
    end
    % Reset figure
    if ~isempty(Digitize.hFig) && ishandle(Digitize.hFig)
        %close(Digitize.hFig);
        bst_figures('DeleteFigure', Digitize.hFig, []);
    end
    Digitize.iDS = [];
    
    % Clear out any existing collection
    ctrl.jLabelFidMessage.setText('');
%     ctrl.jLabelCoilMessage.setText('');
    RemoveCoordinates([]);
    % Reset buttons
    ctrl.jButtonEEGStart.setEnabled(0);
    ctrl.jTextFieldEEG.setEnabled(0);
    ctrl.jButtonExtraStart.setEnabled(0);
    ctrl.jTextFieldExtra.setEnabled(0);
%             if Digitize.Options.isMEG
%                 ctrl.jButtonhpiN.setEnabled(1);
%                 ctrl.jButtonhpiL.setEnabled(1);
%                 ctrl.jButtonhpiR.setEnabled(1);
%                 ctrl.jButtonNasion.setEnabled(0);
%                 ctrl.jButtonLPA.setEnabled(0);
%                 ctrl.jButtonRPA.setEnabled(0);
%                 ctrl.jButtonDeletePoint.setEnabled(0);
%                 % always switch to next mode to start with the nasion
%                 SwitchToNewMode(1);
%             else
%                 ctrl.jButtonhpiN.setEnabled(0);
%                 ctrl.jButtonhpiL.setEnabled(0);
%                 ctrl.jButtonhpiR.setEnabled(0);
%                 ctrl.jButtonNasion.setEnabled(1);
%                 ctrl.jButtonLPA.setEnabled(1);
%                 ctrl.jButtonRPA.setEnabled(1);
%                 ctrl.jButtonDeletePoint.setEnabled(0);
%                 % always switch to next mode to start with the nasion
%                 SwitchToNewMode(4);
%             end
%     % Start with fids
%     SwitchToNewMode(1);
    % Update list of loaded points

    % Generate list of labeled points
    % Initial fiducials
    for iP = 1:numel(Digitize.Options.Fids)
        Digitize.Points(iP).Label = Digitize.Options.Fids{iP};
        Digitize.Points(iP).Type = 'CARDINAL';
    end
    if Digitize.Options.nFidSets > 1
        Digitize.Points = repmat(Digitize.Points, 1, Digitize.Options.nFidSets);
    end
    % EEG
    [curMontage, nEEG] = GetCurrentMontage();
    for iEEG = 1:nEEG
        Digitize.Points(end+1).Label = curMontage.Labels{iEEG};
        Digitize.Points(end).Type = 'EEG';
    end
    
    % Display list in text box
    UpdateList();
    % Close progress bar
    bst_progress('stop');
end


%% ===== SWITCH TO NEW GUI MODE =====
% INPUTS:
%    - Mode 1 = Center coil
%    - Mode 2 = Left coil
%    - Mode 3 = Right coil
%    - Mode 4 = Nasion
%    - Mode 5 = LPA
%    - Mode 6 = RPA
%    - Mode 7 = EEG
%    - Mode 8 = Headshape
function SwitchToNewMode(mode)
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Select mode
    SetSelectedButton(mode);
    Digitize.Mode = mode;
    
    switch mode
%         % Nasion
%         case 4
%             ctrl.jButtonhpiN.setEnabled(0);
%             ctrl.jButtonhpiL.setEnabled(0);
%             ctrl.jButtonhpiR.setEnabled(0);
%             ctrl.jButtonNasion.setEnabled(1);
%             ctrl.jButtonLPA.setEnabled(1);
%             ctrl.jButtonRPA.setEnabled(1);            
        % EEG
        case 7
            % Get current montage
            [curMontage, nEEG] = GetCurrentMontage();
            % There are EEG electrodes: enter EEG collection
            if (nEEG > 0)
                % Enable buttons
                ctrl.jButtonEEGStart.setEnabled(1);
                ctrl.jTextFieldEEG.setEnabled(1);
            % Else: switch directly to mode 8 (head shape)
            else
                SwitchToNewMode(8);
            end
        % Shape
        case 8
            ctrl.jButtonExtraStart.setEnabled(1);
            ctrl.jTextFieldExtra.setEnabled(1);
    end
end


%% ===== UPDATE LIST =====
function UpdateList()
    global Digitize;
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Define the model
    listModel = javax.swing.DefaultListModel();
    % Add points to list
    iHeadPoints = 0;
    for iP = 1:numel(Digitize.Points)
        if ~isempty(Digitize.Points(iP).Label)
            listModel.addElement(sprintf('%s     %3.3f   %3.3f   %3.3f', Digitize.Points(iP).Label, Digitize.Points(iP).Loc .* 100));
        else % head points
            iHeadPoints = iHeadPoints + 1;
            listModel.addElement(sprintf('%03d     %3.3f   %3.3f   %3.3f', iHeadPoints, Digitize.Points(iP).Loc .* 100));
        end
    end
    % Set this list
    ctrl.jListCoord.setModel(listModel);
    ctrl.jListCoord.repaint();
    drawnow;
    % Scroll down
    %lastIndex = min(listModel.getSize(), 12 + nRecEEG + nHeadShape);
    %selRect = ctrl.jListCoord.getCellBounds(lastIndex-1, lastIndex-1);
    %ctrl.jListCoord.scrollRectToVisible(selRect);
    %ctrl.jListCoord.repaint();
    ctrl.jListCoord.getParent().getParent().repaint();
end


%% ===== SET SELECTED BUTTON =====
function SetSelectedButton(iButton)
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    % Create list of buttons
    jButton = javaArray('javax.swing.JToggleButton', 8);
    jButton(1) = ctrl.jButtonFids;
%     jButton(1) = ctrl.jButtonhpiN;
%     jButton(2) = ctrl.jButtonhpiL;
%     jButton(3) = ctrl.jButtonhpiR;
%     jButton(4) = ctrl.jButtonNasion;
%     jButton(5) = ctrl.jButtonLPA;
%     jButton(6) = ctrl.jButtonRPA;
    jButton(7) = ctrl.jButtonEEGStart;
    jButton(8) = ctrl.jButtonExtraStart;
    % Set the selected button color
    jButton(iButton).setSelected(1);
    jButton(iButton).setForeground(java.awt.Color(.8,0,0));
    % Reset the other buttons colors
    for i = setdiff([1 7 8], iButton)
        if jButton(i).isEnabled()
            color = java.awt.Color(0,0,0);
        else
            color = javax.swing.UIManager.getColor('Label.disabledForeground');
            if isempty(color)
                color = java.awt.Color(.5,.5,.5);
            end
        end
        jButton(i).setForeground(color);
    end
end


%% ===== MANUAL COLLECT CALLBACK ======
function ManualCollect_Callback(h, ev)
    global Digitize
    % Simulation: call the callback directly
    if Digitize.Options.isSimulate
        BytesAvailable_Callback(h, ev);
    % Else: Send a collection request to the Polhemus
    else
        % User clicked the button, collect a point
        fprintf(Digitize.SerialConnection,'P');
        pause(0.2);
    end
end

%% ===== DELETE POINT CALLBACK =====
function DeletePoint_Callback(h, ev) %#ok<INUSD>
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    
    % only remove cardinal points when MEG coils are used for the
    % transformation.
    if ismember(Digitize.Mode, [4 5 6]) && Digitize.Options.isMEG
        % Remove the last cardinal point that was collected
        iPoint = size(Digitize.Points.nasion,1);
        coordInd = (iPoint-1)*3;
        if iPoint == 0
            return; 
        end
        point_type = 'cardinal';
    end
    
    if Digitize.Mode == 7
    	%  find the last EEG point collected
        iPoint = str2double(ctrl.jTextFieldEEG.getText()) - 1;
        if iPoint == 0
            % if no EEG points are collected, delete the last cardinal point
            iPoint = size(Digitize.Points.nasion,1);
            coordInd = (iPoint-1)*3;
            point_type = 'cardinal';
        else
            % delete last EEG point
            point_type = 'eeg';
        end
               
    elseif Digitize.Mode == 8
        % headshape point
        iPoint = str2double(ctrl.jTextFieldExtra.getText()) - 1;
        if iPoint == 0 
            % If no headpoints are collected:
            [tmp, nEEG] = GetCurrentMontage();
            if nEEG > 0
                % check for EEG, then delete the last point
                iPoint = str2double(ctrl.jTextFieldEEG.getText());
                point_type = 'eeg';
            else
                % delete the last cardinal point
                iPoint = size(Digitize.Points.nasion,1);
                coordInd = (iPoint-1)*3;
                point_type = 'cardinal';
            end
        else
            point_type = 'extra';
        end
    end
    
    % Now delete the define point
    switch point_type
        case 'cardinal'
            if size(Digitize.Points.LPA,1) < iPoint
                % The LPA has not been collected, remove the nasion point;
                Digitize.Points.nasion(iPoint,:) = [];
                % Find the index of the cardinal points
                RemoveCoordinates('CARDINAL', coordInd+1);
                SwitchToNewMode(4);  
            elseif size(Digitize.Points.RPA,1) < iPoint
                % The RPA has not been collected, remove the LPA point
                Digitize.Points.LPA(iPoint,:) = [];
                % Find the index of the cardinal points
                RemoveCoordinates('CARDINAL', coordInd+2);
                SwitchToNewMode(5);  
            else
                % One full set has been collected, remove the last RPA point
                Digitize.Points.RPA(iPoint,:) = [];
                % Find the index of the cardinal points
                RemoveCoordinates('CARDINAL', coordInd+3);
                SwitchToNewMode(6);  
            end
        case 'eeg'
            Digitize.Points.EEG(iPoint,:) = [];
            RemoveCoordinates('EEG', iPoint);
            ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(iPoint)));
            SwitchToNewMode(7)
        case 'extra'
            Digitize.Points.headshape(iPoint,:) = [];
            RemoveCoordinates('EXTRA', iPoint);
            ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(iPoint)));
            SwitchToNewMode(8)
    end
    
    % Update coordinates list
    UpdateList();   
end


%% ===== COMPUTE TRANFORMATION and save channel file =====
function ComputeTransform()
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    
    % if MEG coils are used, these will determine the coodinate system
    if Digitize.Options.isMEG
        % find the difference between the first two collections to determine error
        if (size(Digitize.Points.hpiN, 1) > 1)
            diffPoint = Digitize.Points.hpiN(1,:) - Digitize.Points.hpiN(2,:);
            normPoint(1) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.hpiL(1,:) - Digitize.Points.hpiL(2,:);
            normPoint(2) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.hpiR(1,:) - Digitize.Points.hpiR(2,:);
            normPoint(3) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            if any(abs(normPoint) > .005)
                ctrl.jLabelCoilMessage.setText('Difference error exceeds 5 mm');
            end
        end
        % find the average across collections to compute the transformation
        na = mean(Digitize.Points.hpiN,1); % these values are in meters
        la = mean(Digitize.Points.hpiL,1);
        ra = mean(Digitize.Points.hpiR,1);
    
    else
        % if only EEG is used, the cardinal points will determine the
        % coordinate system
        
        % find the difference between the first two collections to determine error
        if (size(Digitize.Points.nasion, 1) > 1)
            diffPoint = Digitize.Points.nasion(1,:) - Digitize.Points.nasion(2,:);
            normPoint(1) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.LPA(1,:) - Digitize.Points.LPA(2,:);
            normPoint(2) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            diffPoint = Digitize.Points.RPA(1,:) - Digitize.Points.RPA(2,:);
            normPoint(3) = sum(sqrt(diffPoint(1)^2+diffPoint(2)^2+diffPoint(3)^2));
            if any(abs(normPoint) > .005)
                ctrl.jLabelFidMessage.setText('Difference error exceeds 5 mm');
            end
        end
        % find the average across collections to compute the transformation
        na = mean(Digitize.Points.nasion,1); % these values are in meters
        la = mean(Digitize.Points.LPA,1);
        ra = mean(Digitize.Points.RPA,1);
    end
    
    % Compute the transformation
    sMRI.SCS.NAS = na*1000; %m => mm for the brainstorm fxn
    sMRI.SCS.LPA = la*1000;
    sMRI.SCS.RPA = ra*1000;
    scsTransf = cs_compute(sMRI, 'scs');
    T = scsTransf.T ./ 1000; % mm => m
    R = scsTransf.R;
    Origin = scsTransf.Origin ./ 1000; %#ok<NASGU> % mm => m
    Digitize.Points.trans = [R, T];

    % Get the channel file
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);
    ChannelMat.HeadPoints.Loc = [];
    ChannelMat.HeadPoints.Label = [];
    ChannelMat.HeadPoints.Type = [];
    % Transform coordinates and save  
    if Digitize.Options.isMEG
        for i = 1:size(Digitize.Points.hpiN,1)
            Digitize.Points.hpiN(i,:)   = ([R, T] * [Digitize.Points.hpiN(i,:) 1]')';
            Digitize.Points.hpiL(i,:)   = ([R, T] * [Digitize.Points.hpiL(i,:) 1]')';
            Digitize.Points.hpiR(i,:)   = ([R, T] * [Digitize.Points.hpiR(i,:) 1]')';

            % Nasion
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,  Digitize.Points.hpiN(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'HPI-N'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'HPI'}];
            % LPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.hpiL(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'HPI-L'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'HPI'}];
            % RPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.hpiR(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'HPI-R'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'HPI'}];
        end
    else
        for i = 1:size(Digitize.Points.nasion,1)
            Digitize.Points.nasion(i,:) = ([R, T] * [Digitize.Points.nasion(i,:) 1]')';
            Digitize.Points.LPA(i,:)    = ([R, T] * [Digitize.Points.LPA(i,:) 1]')';
            Digitize.Points.RPA(i,:)    = ([R, T] * [Digitize.Points.RPA(i,:) 1]')';

            % Nasion
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,  Digitize.Points.nasion(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'NA'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'CARDINAL'}];
            % LPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.LPA(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'LPA'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'CARDINAL'}];
            % RPA
            ChannelMat.HeadPoints.Loc   = [ChannelMat.HeadPoints.Loc,   Digitize.Points.RPA(i,:)'];
            ChannelMat.HeadPoints.Label = [ChannelMat.HeadPoints.Label, {'RPA'}];
            ChannelMat.HeadPoints.Type  = [ChannelMat.HeadPoints.Type,  {'CARDINAL'}];
        end
    end
        
%     save(ChannelFile, '-struct', 'ChannelMat');
    bst_save(ChannelFile, ChannelMat, 'v7');
    
end

%% ===== CREATE FIGURE =====
function CreateHeadpointsFigure()
    global Digitize    
    if isempty(Digitize.hFig) || ~ishandle(Digitize.hFig) || isempty(Digitize.iDS)
        % Get study
        sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
        % Plot head points and save handles in global variable
        [Digitize.hFig, Digitize.iDS] = view_headpoints(file_fullpath(sStudy.Channel.FileName));
        % Hide head surface
        panel_surface('SetSurfaceTransparency', Digitize.hFig, 1, 0.8);
        % Get Digitizer JFrame
        bstContainer = get(bst_get('Panel','Digitize'), 'container');
        % Get maximum figure position
        decorationSize = bst_get('DecorationSize');
        [jBstArea, FigArea] = gui_layout('GetScreenBrainstormAreas', bstContainer.handle{1});
        FigPos = FigArea(1,:) + [decorationSize(1),  decorationSize(4),  - decorationSize(1) - decorationSize(3),  - decorationSize(2) - decorationSize(4)];
        if (FigPos(3) > 0) && (FigPos(4) > 0)
            set(Digitize.hFig, 'Position', FigPos);
        end
        % Remove the close handle function
        set(Digitize.hFig, 'CloseRequestFcn', []);
    end 
end

%% ===== PLOT POINTS and add it to channel file and GlobalData =====
function PlotCoordinate(Loc, Label, Type, iPoint)
    global Digitize GlobalData  
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);

    % Add EEG sensor locations to channel stucture
    if strcmp(Type, 'EEG')
        if isempty(ChannelMat.Channel)
            % first point in the list
            ChannelMat.Channel = db_template('channeldesc');
        end
        ChannelMat.Channel(iPoint).Name = Label;
        ChannelMat.Channel(iPoint).Type = 'EEG';
        ChannelMat.Channel(:,iPoint).Loc = Loc';       
    else   
        ind = size(ChannelMat.HeadPoints.Loc,2) + 1;
        ChannelMat.HeadPoints.Loc(:,ind) = Loc';
        ChannelMat.HeadPoints.Label{ind} = Label;
        ChannelMat.HeadPoints.Type{ind}  = Type;
    end     
    
    save(ChannelFile, '-struct', 'ChannelMat');
    GlobalData.DataSet(Digitize.iDS).HeadPoints  = ChannelMat.HeadPoints;
    GlobalData.DataSet(Digitize.iDS).Channel  = ChannelMat.Channel;
    % Remove old HeadPoints
    hAxes = findobj(Digitize.hFig, '-depth', 1, 'Tag', 'Axes3D');
    hHeadPointsMarkers = findobj(hAxes, 'Tag', 'HeadPointsMarkers');
    hHeadPointsLabels  = findobj(hAxes, 'Tag', 'HeadPointsLabels');
    delete(hHeadPointsMarkers);
    delete(hHeadPointsLabels);
    % View all points in the channel file
    figure_3d('ViewHeadPoints', Digitize.hFig, 1);
    figure_3d('ViewSensors', Digitize.hFig, 1, 1, 0, 'EEG');
    % Hide head surface
    panel_surface('SetSurfaceTransparency', Digitize.hFig, 1, 1);
end

%% ===== EEG CHANGE POINT CALLBACK =====
function EEGChangePoint_Callback(h, ev) %#ok<INUSD>
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    
    initPoint = str2num(ctrl.jTextFieldEEG.getText());
    % restrict to a maximum of points collected or defined max points and minimum of '1'
    [curMontage, nEEG] = GetCurrentMontage();
    newPoint = max(min(initPoint, min(length(Digitize.Points.EEG)+1, nEEG)), 1);
    ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(newPoint)));
end

%% ===== EXTRA CHANGE POINT CALLBACK =====
function ExtraChangePoint_Callback(h, ev) %#ok<INUSD>
    global Digitize
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');
    
    initPoint = str2num(ctrl.jTextFieldExtra.getText()); %#ok<*ST2NM>
    % restrict to a maximum of points collected and minimum of '1'
    newPoint = max(min(initPoint, length(Digitize.Points.headshape)+1), 1);
    ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(newPoint)));
end

%% ===== SAVE CALLBACK =====
% This saves a .pos file, which requires first saving the channel file.
function Save_Callback(h, ev, OutFile) %#ok<INUSD>
    global Digitize
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);
    % GlobalData may not exist here: before 3d figure is created or after it is closed. So fill in
    % ChannelMat from Digitize.Points.
    iHead = 0;
    iChan = 0;
    ChannelMat.Channel = db_template('channeldesc');
    for iP = 1:numel(Digitize.Points)
        if ~isempty(Digitize.Points(iP).Label) && strcmpi(Digitize.Points(iP).Type, 'EEG')
            % Add EEG sensor locations to channel stucture
            iChan = iChan + 1;
            ChannelMat.Channel(iChan).Name = Digitize.Points(iP).Label;
            ChannelMat.Channel(iChan).Type = Digitize.Points(iP).Type;
            ChannelMat.Channel(:,iChan).Loc = Digitize.Points(iP).Loc';
        else % head points
            iHead = iHead + 1;
            iHead = size(ChannelMat.HeadPoints.Loc,2) + 1;
            ChannelMat.HeadPoints.Loc(:,iHead) = Digitize.Points(iP).Loc';
            ChannelMat.HeadPoints.Label{iHead} = Digitize.Points(iP).Label;
            ChannelMat.HeadPoints.Type{iHead}  = Digitize.Points(iP).Type;
        end
    end
    bst_save(ChannelFile, ChannelMat, 'v7');
    if nargin > 2 && ~isempty(OutFile)
        export_channel(ChannelFile, OutFile, 'POLHEMUS', 0);
    else
        export_channel(ChannelFile);
    end
end

%% ===== CREATE MONTAGE MENU =====
function CreateMontageMenu(jMenu)
    global Digitize
    % Get menu pointer if not in argument
    if (nargin < 1) || isempty(jMenu)
        ctrl = bst_get('PanelControls', 'Digitize');
        jMenu = ctrl.jMenuEeg;
    end
    % Empty menu
    jMenu.removeAll();
    % Button group
    buttonGroup = javax.swing.ButtonGroup();
    % Display all the montages
    for i = 1:length(Digitize.Options.Montages)
        jMenuMontage = gui_component('RadioMenuItem', jMenu, [], Digitize.Options.Montages(i).Name, buttonGroup, [], @(h,ev)bst_call(@SelectMontage, i), []);
        if (i == 2) && (length(Digitize.Options.Montages) > 2)
            jMenu.addSeparator();
        end
        if (i == Digitize.Options.iMontage)
            jMenuMontage.setSelected(1);
        end
    end
    % Add new montage / reset list
    jMenu.addSeparator();
    gui_component('MenuItem', jMenu, [], 'Add EEG montage...', [], [], @(h,ev)bst_call(@AddMontage), []);
    gui_component('MenuItem', jMenu, [], 'Unload all montages', [], [], @(h,ev)bst_call(@UnloadAllMontages), []);
end


%% ===== SELECT MONTAGE =====
function SelectMontage(iMontage)
    global Digitize
    % Default montage: ask for number of channels
    if (iMontage == 2)
        % Get previous number of electrodes
        nEEG = length(Digitize.Options.Montages(iMontage).Labels);
        if (nEEG == 0)
            nEEG = 56;
        end
        % Ask user for the number of electrodes
        res = java_dialog('input', 'Number of EEG channels in your montage:', 'Default EEG montage', [], num2str(nEEG));
        if isempty(res) || isnan(str2double(res))
            CreateMontageMenu();
            return;
        end
        nEEG = str2double(res);
        % Create default montage
        Digitize.Options.Montages(iMontage).Name = sprintf('Default (%d)', nEEG);
        Digitize.Options.Montages(iMontage).Labels = {};
        for i = 1:nEEG
            if (nEEG > 99)
                strFormat = 'EEG%03d';
            else
                strFormat = 'EEG%02d';
            end
            Digitize.Options.Montages(iMontage).Labels{i} = sprintf(strFormat, i);
        end
    end
    % Save currently selected montage
    Digitize.Options.iMontage = iMontage;
    % Save Digitize options
    bst_set('DigitizeOptions', Digitize.Options);
    % Update menu
    CreateMontageMenu();
    % Restart acquisition
    ResetDataCollection();
end

%% ===== GET CURRENT MONTAGE =====
function [curMontage, nEEG] = GetCurrentMontage()
    global Digitize
    % Return current montage
    curMontage = Digitize.Options.Montages(Digitize.Options.iMontage);
    nEEG = length(curMontage.Labels);
end

%% ===== ADD EEG MONTAGE =====
function AddMontage()
    global Digitize
    % Get recently used folders
    LastUsedDirs = bst_get('LastUsedDirs');
    % Open file
    MontageFile = java_getfile('open', 'Select montage file...', LastUsedDirs.ImportChannel, 'single', 'files', ...
                   {{'*.txt'}, 'Text files', 'TXT'}, 0);
    if isempty(MontageFile)
        return;
    end
    % Get filename
    [MontageDir, MontageName] = bst_fileparts(MontageFile);
    % Intialize new montage
    newMontage.Name = MontageName;
    newMontage.Labels = {};
    
    % Open file
    fid = fopen(MontageFile,'r');
    if (fid == -1)
        error('Cannot open file.');
    end
    % Read file
    while (1)
        tline = fgetl(fid);
        if ~ischar(tline)
            break;
        end
        spl = regexp(tline,'\s+','split');
        if (length(spl) >= 2)
            newMontage.Labels{end+1} = spl{2};
        end
    end
    % Close file
    fclose(fid);
    % If no labels were read: exit
    if isempty(newMontage.Labels)
        return
    end
    % Save last dir
    LastUsedDirs.ImportChannel = MontageDir;
    bst_set('LastUsedDirs', LastUsedDirs);
    
    % Get existing montage with the same name
    iMontage = find(strcmpi({Digitize.Options.Montages.Name}, newMontage.Name));
    % If not found: create new montage entry
    if isempty(iMontage)
        iMontage = length(Digitize.Options.Montages) + 1;
    else
        iMontage = iMontage(1);
        disp('DIGITIZER> Warning: Montage name already exists. Overwriting...');
    end
    % Add new montage to registered montages
    Digitize.Options.Montages(iMontage) = newMontage;
    Digitize.Options.iMontage = iMontage;
    % Save options
    bst_set('Digitize.Options', Digitize.Options);
    % Reload Menu
    CreateMontageMenu();
    % Restart acquisition
    ResetDataCollection();
end

%% ===== UNLOAD ALL MONTAGES =====
function UnloadAllMontages()
    global Digitize
    % Remove all montages
    Digitize.Options.Montages = [...
        struct('Name',   'No EEG', ...
               'Labels', []), ...
        struct('Name',   'Default', ...
               'Labels', [])];
    % Reset to "No EEG"
    Digitize.Options.iMontage = 1;
    % Save Digitize options
    bst_set('Digitize.Options', Digitize.Options);
    % Reload menu bar
    CreateMontageMenu();
end


%% ===== REMOVE POINTS =====
function RemoveCoordinates(type, iPoint)
% type: CARDINAL, EEG, EXTRA, leave empty to delete all headpoints
% iPoint: the index of the point to delete wthin the group, leave empty to delete the entire group
% TODO remove the points from the coordinate list also
    global GlobalData Digitize    
    
    sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
    ChannelFile = file_fullpath(sStudy.Channel.FileName);
    ChannelMat = load(ChannelFile);
    if isempty(type)
        % remove all points
        ChannelMat.HeadPoints = [];
        ChannelMat.Channel = [];
        % Save file back
        save(ChannelFile, '-struct', 'ChannelMat');
        % close the figure
        if ishandle(Digitize.hFig)
            %close(Digitize.hFig);
            bst_figures('DeleteFigure', Digitize.hFig, []);
        end
    else
        % find group and remove selected point        
        if isempty(iPoint)
            % create a mask of points to keep that exclude the specified
            % type
            mask = cellfun(@isempty,regexp([ChannelMat.HeadPoints.Type], type));
            ChannelMat.HeadPoints.Loc = ChannelMat.HeadPoints.Loc(:,mask);
            ChannelMat.HeadPoints.Label = ChannelMat.HeadPoints.Label(mask);
            ChannelMat.HeadPoints.Type = ChannelMat.HeadPoints.Type(mask);
            if strcmp(type, 'EEG')
                % remove all EEG channels from channel struct
                ChannelMat.Channel = [];
            end
        else
            % find the point in the type and create a mask of points to keep
            % that excludes the specified point
            if strcmp(type, 'EEG')
                % remove specific EEG channel
                ChannelMat.Channel(iPoint) = [];
            else
                %  all other types
                iType = find(~cellfun(@isempty,regexp([ChannelMat.HeadPoints.Type], type)));
                mask = true(1,size(ChannelMat.HeadPoints.Type,2));
                mask(iType(iPoint)) = false;
                ChannelMat.HeadPoints.Loc = ChannelMat.HeadPoints.Loc(:,mask);
                ChannelMat.HeadPoints.Label = ChannelMat.HeadPoints.Label(mask);
                ChannelMat.HeadPoints.Type = ChannelMat.HeadPoints.Type(mask);
            end
            
        end
        % save changes
        save(ChannelFile, '-struct', 'ChannelMat');
        GlobalData.DataSet(Digitize.iDS).HeadPoints  = ChannelMat.HeadPoints;
        GlobalData.DataSet(Digitize.iDS).Channel  = ChannelMat.Channel;
        % Remove old HeadPoints
        hAxes = findobj(Digitize.hFig, '-depth', 1, 'Tag', 'Axes3D');
        hHeadPointsMarkers = findobj(hAxes, 'Tag', 'HeadPointsMarkers');
        hHeadPointsLabels  = findobj(hAxes, 'Tag', 'HeadPointsLabels');
        hHeadPointsFid = findobj(hAxes, 'Tag', 'HeadPointsFid');
        delete(hHeadPointsMarkers);
        delete(hHeadPointsLabels);
        delete(hHeadPointsFid);
        % View headpoints
        figure_3d('ViewHeadPoints', Digitize.hFig, 1);
        
        % manually remove any remaining EEG markers if the channel file is empty. 
        if isempty(ChannelMat.Channel)
            hSensorMarkers = findobj(hAxes, 'Tag', 'SensorsMarkers');
            hSensorLabels  = findobj(hAxes, 'Tag', 'SensorsLabels');
            delete(hSensorMarkers);
            delete(hSensorLabels);
        end
        
        % view EEG sensors
        figure_3d('ViewSensors',Digitize.hFig, 1, 1, 0,'EEG');     
    end
    
    Digitize.iPoint = Digitize.iPoint - 1;
    % If we're down to initial fids only, change delete button label and callback to "restart" instead of delete.
    if Digitize.iPoint <= numel(Digitize.Options.Fids) * Digitize.Options.nFidSets
        java_setcb(ctrl.jButtonDeletePoint, 'ActionPerformedCallback', @ResetDataCollection);
        ctrl.jButtonDeletePoint.setText('Start over');
    end
end


%% ========================================================================
%  ======= POLHEMUS COMMUNICATION =========================================
%  ========================================================================

%% ===== CREATE SERIAL COLLECTION =====
function isOk = CreateSerialConnection(h, ev) %#ok<INUSD>
    global Digitize 
    isOk = 0;
    while ~isOk
        % Simulation: exit
        if Digitize.Options.isSimulate
            isOk = 1;
            return;
        end
        % Check for existing open connection
        s = instrfind('status','open');
        if ~isempty(s)
            fclose(s);
        end
        % Create connection
%         Digitize.Options.ComRate = 115200;
        SerialConnection = serial(Digitize.Options.ComPort, 'BaudRate', Digitize.Options.ComRate);
        if strcmp(Digitize.Options.UnitType,'patriot')
            SerialConnection.terminator = 'CR';
        end
        % set up the Bytes Available function and open the connection (if needed)
        SerialConnection.BytesAvailableFcnCount = Digitize.Options.ComByteCount;
        SerialConnection.BytesAvailableFcnMode  = 'byte';
        SerialConnection.BytesAvailableFcn      = @BytesAvailable_Callback;
%         SerialConnection.BytesAvailableFcn      = @BytesAvailableDebug_Callback;
        if (strcmp(SerialConnection.status,'closed'))
            try
                % Open connection
                fopen(SerialConnection); 
                if strcmp(Digitize.Options.UnitType,'fastrak')
                    %'c' - Disable Continuous Printing
                    % Required for some configuration options.
                    fprintf(SerialConnection,'c');
                    %'u' - Metric Conversion Units (set units to cm)
                    fprintf(SerialConnection,'u');
                    %'F' - Enable ASCII Output Format
                    fprintf(SerialConnection,'F');
                    %'R' - Reset Alignment Reference Frame
                    fprintf(SerialConnection,'R1');
                    fprintf(SerialConnection,'R2');
                    %'A' - Alignment Reference Frame
                    %'H' - Hemisphere of Operation
                    fprintf(SerialConnection,'H1,0,0,-1'); % -Z hemisphere
                    fprintf(SerialConnection,'H2,0,0,-1'); % -Z hemisphere
                    %'l' - Active Station State
                    % Could check here if 1 and 2 are active.
                    %'N' - Define Tip Offsets % Always factory default on power-up.
                    %    fprintf(SerialConnection,'N1'); data = fscanf(SerialConnection)
                    %    data = '21N  6.344  0.013  0.059
                    %'O' - Output Data List
                    fprintf(SerialConnection,'O1,2,4,1'); % default precision: position, Euler angles, CRLF
                    fprintf(SerialConnection,'O2,2,4,1'); % default precision: position, Euler angles, CRLF
                    %fprintf(SerialConnection,'O1,52,54,51'); % extended precision: position, Euler angles, CRLF
                    %fprintf(SerialConnection,'O2,52,54,51'); % extended precision: position, Euler angles, CRLF
                    %'Q' - Angular Operational Envelope
                    fprintf(SerialConnection,'Q1,180,90,180,-180,-90,-180');
                    fprintf(SerialConnection,'Q2,180,90,180,-180,-90,-180');
                    %'V' - Position Operational Envelope
                    % Could use to warn if too far.
                    fprintf(SerialConnection,'V1,100,100,100,-100,-100,-100');
                    fprintf(SerialConnection,'V2,100,100,100,-100,-100,-100');
                    %'x' - Position Filter Parameters
                    % The macro setting used here also applies to attitude filtering.
                    % 1=none, 2=low, 3=medium (default), 4=high
                    fprintf(SerialConnection,'x3');
                    
                    %'e' - Define Stylus Button Function
                    fprintf(SerialConnection,'e1,1'); % Point mode
                    
                    %'^K' - *Save Operational Configuration
                    % 'ctrl+K' = char(11)
                    %'^Y' - *Reinitialize System
                    % 'ctrl+Y' = char(25)
                elseif strcmp(Digitize.Options.UnitType,'patriot')
                    % request input from stylus
                    fprintf(SerialConnection,'L1,1\r');
                    % Set units to centimeters
                    fprintf(SerialConnection,'U1\r');
                end
                pause(0.2);
            catch %#ok<CTCH>
                % If the connection cannot be established: error message
                bst_error(['Cannot open serial connection.' 10 10 'Please check the serial port configuration.' 10], 'Digitize', 0);
                % Ask user to edit the port options
                isChanged = EditSettings();
                % If edit was canceled: exit
                if ~isChanged
                    %SerialConnection = [];
                    return
                % If not, try again
                else
                    continue;
                end
            end
        end
        % Save the current connection in global variable
        Digitize.SerialConnection = SerialConnection;
        isOk = 1;
    end
end


%% Debug callback
% function BytesAvailableDebug_Callback(h, ev) %#ok<INUSD>
%     global Digitize
%     data = fscanf(Digitize.SerialConnection)
% end

%% ===== BYTES AVAILABLE CALLBACK =====
function BytesAvailable_Callback(h, ev) %#ok<INUSD>
    global Digitize rawpoints
    % Get controls
    ctrl = bst_get('PanelControls', 'Digitize');

    % Simulate: Generate random points
    if Digitize.Options.isSimulate
        switch (Digitize.Mode)
            case 1,     Digitize.Points(Digitize.iPoint).Loc = [.08 0 -.01];
            case 2,     Digitize.Points(Digitize.iPoint).Loc = [-.01 .07 0];
            case 3,     Digitize.Points(Digitize.iPoint).Loc = [-.01 -.07 0];
            case 4,     Digitize.Points(Digitize.iPoint).Loc = [.08 0 0];
            case 5,     Digitize.Points(Digitize.iPoint).Loc = [0  .07 0];
            case 6,     Digitize.Points(Digitize.iPoint).Loc = [0 -.07 0];
            otherwise,  Digitize.Points(Digitize.iPoint).Loc = rand(1,3) * .15 - .075;
        end
    % Else: Get digitized point coordinates
    else
        vals = zeros(1,7); % header, x, y, z, azimuth, elevation, roll
        rawpoints = zeros(2,7); % 2 receivers
        data = [];
        try
            for j=1:2 % 1 point * 2 receivers
                data = fscanf(Digitize.SerialConnection);
                if strcmp(Digitize.Options.UnitType, 'fastrak')
                    % This is fastrak
                    % The factory default ASCII output record x-y-z-azimuth-elevation-roll is composed of 
                    % 47 bytes (3 status bytes, 6 data words each 7 bytes long, and a CR LF terminator)
                    vals(1) = str2double(data(1:3)); % header is first three char
                    for v=2:7
                        % next 6 values are each 7 char
                        ind=(v-1)*7;
                        vals(v) = str2double(data((ind-6)+3:ind+3));
                    end
                elseif strcmp(Digitize.Options.UnitType, 'patriot')
                    % This is patriot
                    % The factory default ASCII output record x-y-z-azimuth-elevation-roll is composed of 
                    % 60 bytes (4 status bytes, 6 data words each 9 bytes long, and a CR LF terminator)
                    vals(1) = str2double(data(1:4)); % header is first 5 char
                    for v=2:7
                        % next 6 values are each 9 char
                        ind=(v-1)*9;
                        vals(v) = str2double(data((ind-8)+4:ind+4));
                    end
                end
                rawpoints(j,:) = vals;
            end
        catch
            disp(['Error reading data point. Try again.' 10, ...
                'If the problem persits, reset the serial connnection.' 10, ...
                data]);
            return;
        end
        % Motion compensation and conversion to meters 
        % This is not converting to SCS, but to another digitizer-specific head-fixed coordinate system.
        Digitize.Points(Digitize.iPoint).Loc = DoMotionCompensation(rawpoints) ./100; % cm => meters
    end
    % Beep at each click AND not for headshape points
    if Digitize.Options.isBeep 
        % Beep not working in compiled version, replacing with this:
        if bst_iscompiled() && (Digitize.Mode ~= 8)
            sound(Digitize.BeepWav(6000:2:16000,1), 22000);
        else
            beep on;
            beep();
        end
    end

    % Increment current point index
    Digitize.iPoint = Digitize.iPoint + 1;
    if Digitize.iPoint > numel(Digitize.Points)
        Digitize.Points(Digitize.iPoint).Type = 'EXTRA';
    end
    % Transform coordinates
    if ~isempty(Digitize.Transf)
        Digitize.Points(Digitize.iPoint).Loc = [Digitize.Points(Digitize.iPoint).Loc 1] * Digitize.Transf';
    end
    % Update coordinates list
    UpdateList();
    % Update counters
    switch upper(Digitize.Points(Digitize.iPoint).Type)
        case 'EXTRA'
            iCount = str2double(ctrl.jTextFieldExtra.getText());
            ctrl.jTextFieldExtra.setText(num2str(iCount + 1));
        case 'EEG'
            iCount = str2double(ctrl.jTextFieldEEG.getText());
            ctrl.jTextFieldEEG.setText(num2str(iCount + 1));
    end
    if ~isempty(Digitize.hFig) && ishandle(Digitize.hFig)
% Save in GlobalData...ChannelFile.Headpoints or Sensors?, but NOT in actual channel file 
% 
% update figure 
    end           
%         % === EEG ===
%         case 7
%             % find the index for the current point
%             iPoint = str2double(ctrl.jTextFieldEEG.getText());
%             PlotCoordinate(Digitize.Points.EEG(iPoint,:), curMontage.Labels{iPoint}, 'EEG', iPoint)
%             % update text field counter to the next point in the list
%             
%                 ctrl.jTextFieldEEG.setText(java.lang.String.valueOf(int16(nextPoint)));
%         % === EXTRA ===
%         case 8
%             % find the index for the current point in the headshape points
%             iPoint = str2double(ctrl.jTextFieldExtra.getText());
%             % add the point to the display (in cm)
%             PlotCoordinate(Digitize.Points.headshape(iPoint,:), 'EXTRA', 'EXTRA', iPoint)
%             % update text field counter to the next point in the list
%             nextPoint = iPoint+1;
%             ctrl.jTextFieldExtra.setText(java.lang.String.valueOf(int16(nextPoint)));

    % When initial fids are all collected
    if Digitize.iPoint == numel(Digitize.Options.Fids) * Digitize.Options.nFidSets
        % Save temp pos file
        TmpDir = bst_get('BrainstormTmpDir');
        TmpPosFile = bst_fullfile(TmpDir, [Digitize.SubjectName '_' matlab.lang.makeValidName(Digitize.ConditionName) '.pos']);
        Save_Callback([], [], TmpPosFile);

        % Empty points from channel file (used to create the temp .pos file) to then re-import that
        % .pos file. This is the simplest way to set up the coordinates, reusing usual Brainstorm
        % functions.
        sStudy = bst_get('StudyWithCondition', [Digitize.SubjectName '/' Digitize.ConditionName]);
        ChannelFile = file_fullpath(sStudy.Channel.FileName);
        ChannelMat = load(ChannelFile);
        ChannelMat.Channel = db_template('channeldesc');
        ChannelMat.HeadPoints.Loc = [];
        ChannelMat.HeadPoints.Label = [];
        ChannelMat.HeadPoints.Type = [];
        bst_save(ChannelFile, ChannelMat, 'v7');

        % import_channel -> in_channel_pos, channel_detect_type
        FileMat = import_channel(Digitize.iStudy, TmpPosFile, 'POLHEMUS', 0, 0, 0, 1, 0); % don't save, fix units
        % Delete temp file
        file_delete(TmpPosFile, 1);
        Digitize.Transf = FileMat.TransfMeg{end}(1:3,:); % 3x4 transform matrix
        if isempty(Digitize.Transf)
            error('Missing coordinate transformation');
        end
        % Copy imported points (with coordinates transformed)
        % Updating the channel file is not necessary at this stage, but safer to save these essential points.
        ChannelMat.Channel = FileMat.Channel; % There shouldn't be any EEG yet, so this should be empty
        ChannelMat.HeadPoints = FileMat.HeadPoints;
        bst_save(ChannelFile, ChannelMat, 'v7');
        % Update coordinates
        for iP = 1:numel(Digitize.Points)
            Digitize.Points(iP).Loc = [Digitize.Points(iP).Loc, 1] * Digitize.Transf';
        end
        
        % Create figure, store hFig & iDS
        CreateHeadpointsFigure();
        % Enable fids button
        ctrl.jButtonFids.setEnabled(1);
    elseif Digitize.iPoint == numel(Digitize.Options.Fids) * Digitize.Options.nFidSets + 1
        % Change delete button label and callback such that we can delete the last point.
        java_setcb(ctrl.jButtonDeletePoint, 'ActionPerformedCallback', @DeletePoint_Callback);
        ctrl.jButtonDeletePoint.setText('Delete last point');
    end
end


%% ===== MOTION COMPENSATION =====
function newPT = DoMotionCompensation(sensors)
    % use sensor one and its orientation vectors as the new coordinate system
    % Define the origin as the position of sensor attached to the glasses.
    WAND = 1;
    REMOTE1 = 2;

    C(1) = sensors(REMOTE1,2);
    C(2) = sensors(REMOTE1,3);
    C(3) = sensors(REMOTE1,4);

    % Deg2Rad = (angle / 180) * pi
    % alpha = Deg2Rad(sensors(REMOTE1).o.Azimuth)
    % beta = Deg2Rad(sensors(REMOTE1).o.Elevation)
    % gamma = Deg2Rad(sensors(REMOTE1).o.Roll)

    alpha = (sensors(REMOTE1,5)/180) * pi;
    beta = (sensors(REMOTE1,6)/180) * pi;
    gamma = (sensors(REMOTE1,7)/180) * pi;

    SA = sin(alpha);
    SE = sin(beta);
    SR = sin(gamma);
    CA = cos(alpha);
    CE = cos(beta);
    CR = cos(gamma);

    % Convert Euler angles to directional cosines
    % using formulae in Polhemus manual.
    rotMat(1, 1) = CA * CE;
    rotMat(1, 2) = SA * CE;
    rotMat(1, 3) = -SE;

    rotMat(2, 1) = CA * SE * SR - SA * CR;
    rotMat(2, 2) = CA * CR + SA * SE * SR;
    rotMat(2, 3) = CE * SR;

    rotMat(3, 1) = CA * SE * CR + SA * SR;
    rotMat(3, 2) = SA * SE * CR - CA * SR;
    rotMat(3, 3) = CE * CR;

    rotMat(4, 1:4) = 0;

    %Translate and rotate the WAND into new coordinate system
    pt(1) = sensors(WAND,2) - C(1);
    pt(2) = sensors(WAND,3) - C(2);
    pt(3) = sensors(WAND,4) - C(3);

    newPT(1) = pt(1) * rotMat(1, 1) + pt(2) * rotMat(1, 2) + pt(3) * rotMat(1, 3)'+ rotMat(1, 4);
    newPT(2) = pt(1) * rotMat(2, 1) + pt(2) * rotMat(2, 2) + pt(3) * rotMat(2, 3)'+ rotMat(2, 4);
    newPT(3) = pt(1) * rotMat(3, 1) + pt(2) * rotMat(3, 2) + pt(3) * rotMat(3, 3)'+ rotMat(3, 4);
end




