function tutorial_practicalmeeg(bids_dir, reports_dir)
% TUTORIAL_PRACTICALMEEG: Runs the first subject of Brainstorm/SPM group analysis pipeline
%
% WORKSHOP PAGE : https://neuroimage.usc.edu/brainstorm/WorkshopParis2019
% FULL TUTORIAL : https://neuroimage.usc.edu/brainstorm/Tutorials/VisualSingle
%
% INPUTS:
%    - bids_dir: Path to folder ds000117-practical  (https://owncloud.icm-institute.org/index.php/s/cNu5jmiOhe7Yuoz/download)
%       |- derivatives/freesurfer/sub-01                               : Segmentation folder generated with FreeSurfer
%       |- derivatives/meg_derivatives/sub-01/ses-meg/meg/*.fif        : MEG+EEG recordings (processed with MaxFilter's SSS)
%       |- derivatives/meg_derivatives/sub-emptyroom/ses-meg/meg/*.fif : Empty room measurements (processed with MaxFilter's SSS)
%    - reports_dir: If defined, exports all the reports as HTML to this folder

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
% Author: Francois Tadel, 2019


%% ===== INPUTS =====
% Parse command line
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% Script variables
ProtocolName = 'PracticalMEEG';
SubjectName = 'sub-01';
AnatDir   = fullfile(bids_dir, 'derivatives', 'freesurfer', SubjectName, 'ses-mri', 'anat');
FifFile   = fullfile(bids_dir, 'derivatives', 'meg_derivatives', SubjectName, 'ses-meg', 'meg', [SubjectName, '_ses-meg_task-facerecognition_run-01_proc-sss_meg.fif']);
NoiseFile = fullfile(bids_dir, 'derivatives', 'meg_derivatives', 'sub-emptyroom', 'ses-20090409', 'meg', 'sub-emptyroom_ses-20090409_task-noise_proc-sss_meg.fif');
% Check input folder
if (nargin < 1) || isempty(bids_dir) || ~exist(AnatDir,'file') || ~exist(FifFile,'file') || ~exist(NoiseFile,'file')
    error('The first argument must be the full path to the tutorial folder.');
end


%% ===== START BRAINSTORM =====
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Disable visualization filters
panel_filter('SetFilters', 0, [], 0, [], 0, [], 0, 0);
% Restore all colormaps
bst_colormaps('RestoreDefaults', 'anatomy');
bst_colormaps('RestoreDefaults', 'meg');
bst_colormaps('RestoreDefaults', 'eeg');
bst_colormaps('RestoreDefaults', 'source');
bst_colormaps('RestoreDefaults', 'stat1');
bst_colormaps('RestoreDefaults', 'stat2');
bst_colormaps('RestoreDefaults', 'time');
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
% Start a new execution report
bst_report('Start');


%% ===== 1. FROM RAW TO ERP =====
% === LINK CONTINUNOUS FILE ===
% Process: Create link to raw file
sFileRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {FifFile, 'FIF'}, ...
    'channelreplace', 1, ...
    'channelalign',   0);
% Process: Set channels type
bst_process('CallProcess', 'process_channel_settype', sFileRaw, [], ...
    'sensortypes', 'EEG061, EEG064', ...
    'newtype',     'Misc');
bst_process('CallProcess', 'process_channel_settype', sFileRaw, [], ...
    'sensortypes', 'EEG062', ...
    'newtype',     'EOG');
bst_process('CallProcess', 'process_channel_settype', sFileRaw, [], ...
    'sensortypes', 'EEG063', ...
    'newtype',     'ECG');

% === IMPORT TRIGGERS ===
% Process: Read from channel
bst_process('CallProcess', 'process_evt_read', sFileRaw, [], ...
    'stimchan',  'STI101', ...
    'trackmode', 1, ...  % Value: detect the changes of channel value
    'zero',      0);
% Process: Merge events
bst_process('CallProcess', 'process_evt_merge', sFileRaw, [], ...
    'evtnames', '5,6,7', ...
    'newname',  'Famous');
% Process: Merge events
bst_process('CallProcess', 'process_evt_merge', sFileRaw, [], ...
    'evtnames', '13,14,15', ...
    'newname',  'Unfamiliar');
% Process: Merge events
bst_process('CallProcess', 'process_evt_merge', sFileRaw, [], ...
    'evtnames', '17,18,19', ...
    'newname',  'Scrambled');
% Get all the other events
sMat = in_bst_data(sFileRaw.FileName);
otherEvt = setdiff({sMat.F.events.label}, {'Famous', 'Unfamiliar', 'Scrambled'});
% Process: Delete events
bst_process('CallProcess', 'process_evt_delete', sFileRaw, [], ...
    'eventname', sprintf('%s,', otherEvt{:}));
% Process: Add time offset
bst_process('CallProcess', 'process_evt_timeoffset', sFileRaw, [], ...
    'info',      [], ...
    'eventname', 'Famous, Unfamiliar, Scrambled', ...
    'offset',    0.0345);

% === FREQUENCY FILTERS ===
% Process: Power spectrum density (Welch)
sFilesPsd = bst_process('CallProcess', 'process_psd', sFileRaw, [], ...
    'timewindow',  [250,300], ...
    'win_length',  4, ...
    'win_overlap', 50, ...
    'sensortypes', 'MEG, EEG', ...
    'edit', struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0));
% Process: Snapshot: Frequency spectrum
bst_process('CallProcess', 'process_snapshot', sFilesPsd, [], ...
    'target',  10, ...  % Frequency spectrum
    'Comment', 'PSD before cleaning');
% Process: Low-pass:40Hz
sFileClean = bst_process('CallProcess', 'process_bandpass', sFileRaw, [], ...
    'sensortypes', 'MEG, EEG', ...
    'highpass',    0, ...
    'lowpass',     40, ...
    'tranband',    0, ...
    'attenuation', 'strict', ...  % 60dB
    'ver',         '2019', ...  % 2019
    'mirror',      0, ...
    'read_all',    0);

% === EEG: BAD CHANNELS & AVG REF ===
% Process: Set bad channels
bst_process('CallProcess', 'process_channel_setbad', sFileClean, [], ...
        'sensortypes', 'EEG016');
% Process: Re-reference EEG
bst_process('CallProcess', 'process_eegref', sFileClean, [], ...
    'eegref',      'AVERAGE', ...
    'sensortypes', 'EEG');

% ===== DETECT ARTIFACTS ======
% Process: Detect heartbeats
bst_process('CallProcess', 'process_evt_detect_ecg', sFileClean, [], ...
    'channelname', 'EEG063', ...
    'timewindow',  [], ...
    'eventname',   'cardiac');
% Process: Detect eye blinks
bst_process('CallProcess', 'process_evt_detect_eog', sFileClean, [], ...
    'channelname', 'EEG062', ...
    'timewindow',  [], ...
    'eventname',   'blink');
% Process: Merge events
bst_process('CallProcess', 'process_evt_merge', sFileClean, [], ...
    'evtnames', 'blink,blink2', ...
    'newname',  'blink_bad');
% Process: Remove simultaneous
bst_process('CallProcess', 'process_evt_remove_simult', sFileClean, [], ...
    'remove', 'cardiac', ...
    'target', 'blink_bad', ...
    'dt',     0.25, ...
    'rename', 0);

% === CLEANING WITH SSP ===
% Process: SSP ECG: cardiac
bst_process('CallProcess', 'process_ssp_ecg', sFileClean, [], ...
    'eventname',   'cardiac', ...
    'sensortypes', 'MEG GRAD', ...
    'usessp',      1, ...
    'select',      1); 
bst_process('CallProcess', 'process_ssp_ecg', sFileClean, [], ...
    'eventname',   'cardiac', ...
    'sensortypes', 'MEG MAG', ...
    'usessp',      1, ...
    'select',      1);
% Process: Snapshot: SSP projectors
bst_process('CallProcess', 'process_snapshot', sFileClean, [], ...
    'target',   2, ...  % SSP projectors
    'Comment',  'Heartbeats: Removed SSP components');   

% === QUALITY CONTROL ===
% Process: Power spectrum density (Welch)
sFilesPsdClean = bst_process('CallProcess', 'process_psd', sFileClean, [], ...
    'timewindow',  [250,300], ...
    'win_length',  4, ...
    'win_overlap', 50, ...
    'sensortypes', 'MEG, EEG', ...
    'edit', struct(...
         'Comment',         'Power', ...
         'TimeBands',       [], ...
         'Freqs',           [], ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0));
% Process: Snapshot: Frequency spectrum
bst_process('CallProcess', 'process_snapshot', sFilesPsdClean, [], ...
    'target',   10, ...  % Frequency spectrum
    'Comment',  'PSD after cleaning');


%% ===== 2. SENSOR-LEVEL ANALYSIS =====
% === IMPORT EPOCHS ===
% Process: Import MEG/EEG: Events
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFileClean, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'eventname',   'Famous, Scrambled, Unfamiliar', ...
    'timewindow',  [], ...
    'epochtime',   [-0.5, 1.2], ...
    'createcond',  0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        [], ...
    'baseline',    [-0.5, -0.0009]);
% Display EEG065 in all trials
hFig = view_erpimage({sFilesEpochs.FileName}, 'erpimage', 'EEG');
panel_display('SetSelectedPage', hFig, 'EEG065');
bst_report('Snapshot', hFig, sFilesEpochs(1).FileName, 'EEG065 for all imported epochs', [200,200,800,600]);
close(hFig);

% === AVERAGE ===
% Process: Average: By trial group (folder average)
sFilesAvg = bst_process('CallProcess', 'process_average', sFilesEpochs, [], ...
    'avgtype',    5, ...  % By trial group (folder average)
    'avg_func',   1, ...  % Arithmetic average:  mean(x)
    'weighted',   0, ...
    'keepevents', 0);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 4, ...  % EEG
    'time',     0.085, ...
    'Comment',  'Average EEG');
% Process: Snapshot: Recordings topography (contact sheet)
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',         7, ...  % Recordings topography (contact sheet)
    'modality',       4, ...  % EEG
    'contact_time',   [0, 0.3], ...
    'contact_nimage', 16, ...
    'Comment',        'Average EEG');
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 1, ...  % MEG (all)
    'time',     0.085, ...
    'Comment',  'Average MEG (all)');
% Process: Snapshot: Recordings topography (contact sheet)
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',         7, ...  % Recordings topography (contact sheet)
    'modality',       1, ...  % MEG (all)
    'contact_time',   [0, 0.3], ...
    'contact_nimage', 16, ...
    'Comment',        'Average MEG (all)');
% Display 2DLayout with 3 conditions
hFig = view_topography({sFilesAvg.FileName}, 'EEG', '2DLayout');
bst_report('Snapshot', hFig, sFilesAvg(1).FileName, 'EEG average (2D Layout)', [200,200,800,600]);
close(hFig);
% Display EEG056 signals in all conditions
hFigMeg = view_timeseries(sFilesAvg(1).FileName);
[Clust, iClust] = panel_cluster('CreateNewCluster', {'EEG065'});
hFig = view_clusters({sFilesAvg.FileName}, iClust, [], struct('function', 'Mean', 'overlayClusters', 0, 'overlayConditions', 1));
bst_report('Snapshot', hFig, sFilesAvg(1).FileName, 'EEG065');
close([hFig, hFigMeg]);

% === TIME-FREQUENCY: WAVELETS ===
% Process: Select file comments with tag: Famous
sFilesEpochsFamous = bst_process('CallProcess', 'process_select_tag', sFilesEpochs, [], ...
    'tag',    'Famous', ...
    'search', 2, ...  % Search the file comments
    'select', 1);     % Select only the files with the tag
% Process: Time-frequency (Morlet wavelets)
sTfFamous = bst_process('CallProcess', 'process_timefreq', sFilesEpochsFamous, [], ...
    'sensortypes', 'EEG', ...
    'edit',        struct(...
         'Comment',         'Avg,Power,1-60Hz', ...
         'TimeBands',       [], ...
         'Freqs',           [1, 1.4, 1.8, 2.3, 2.7, 3.3, 3.8, 4.4, 5, 5.6, 6.3, 7, 7.8, 8.6, 9.4, 10.3, 11.3, 12.3, 13.4, 14.6, 15.8, 17.1, 18.5, 19.9, 21.5, 23.1, 24.9, 26.7, 28.7, 30.8, 33, 35.3, 37.8, 40.4, 43.2, 46.2, 49.4, 52.7, 56.2, 60], ...
         'MorletFc',        1, ...
         'MorletFwhmTc',    3, ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'average', ...
         'RemoveEvoked',    0, ...
         'SaveKernel',      0), ...
    'normalize',   'none');  % None: Save non-standardized time-frequency maps
% Process: Z-score transformation: [-200ms,-1ms]
sTfFamousNorm = bst_process('CallProcess', 'process_baseline_norm', sTfFamous, [], ...
    'baseline',  [-0.2, -0.0009], ...
    'method',    'zscore', ...  % Z-score transformation:    x_std = (x - &mu;) / &sigma;
    'overwrite', 0);
% Process: Extract time: [-200ms,900ms]
sTfFamousNorm = bst_process('CallProcess', 'process_extract_time', sTfFamousNorm, [], ...
    'timewindow', [-0.2, 0.9], ...
    'overwrite',  1);
% Configure colormap
bst_colormaps('SetMaxCustom', 'stat2', [], -30, 30);
% Display 2DLayout
hFig = view_timefreq(sTfFamousNorm.FileName, '2DLayout');
bst_report('Snapshot', hFig, sTfFamousNorm.FileName, 'Famous, EEG: Time-frequency with Morlet wavelets', [200,200,800,600]);
close(hFig);
% Display EEG065
hFig = view_timefreq(sTfFamousNorm.FileName, 'SingleSensor', 'EEG065');
panel_display('SetSmoothDisplay', 1, hFig);
bst_report('Snapshot', hFig, sTfFamousNorm.FileName, 'Famous, EEG065: Time-frequency with Morlet wavelets');
close(hFig);
% Restore colormap
bst_colormaps('RestoreDefaults', 'stat2');



%% ===== 3. CREATING HEAD AND SOURCE MODELS =====
% === IMPORT ANATOMY ===
% Process: Import anatomy folder
bst_process('CallProcess', 'process_import_anatomy', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {AnatDir, 'FreeSurfer'}, ...
    'nvertices',   15000);

% === REGISTRATION MRI-SENSORS ===
% Process: Remove head points
bst_process('CallProcess', 'process_headpoints_remove', sFilesAvg(1), [], ...
    'zlimit', 0);
% Process: Refine registration
bst_process('CallProcess', 'process_headpoints_refine', sFilesAvg(1), []);
% Process: Project electrodes on scalp
bst_process('CallProcess', 'process_channel_project', sFilesAvg(1), []);
% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesAvg(1), [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 1, ...  % MEG (All)
    'orient',   1, ...  % left
    'Comment',  'MEG/MRI Registration');
bst_process('CallProcess', 'process_snapshot', sFilesAvg(1), [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 4, ...  % EEG
    'orient',   1, ...  % left
    'Comment',  'EEG/MRI Registration');

% === FORWARD MODEL ===
% Process: Generate BEM surfaces
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectName, ...
    'nscalp',      642, ...
    'nouter',      482, ...
    'ninner',      482, ...
    'thickness',   4);
% Process: Compute head model (only for the first run of the subject)
bst_process('CallProcess', 'process_headmodel', sFilesAvg(1), [], ...
    'sourcespace', 1, ...  % Cortex surface
    'meg',         3, ...  % Overlapping spheres
    'eeg',         3);     % OpenMEEG BEM

% === SIMULATION ===
% Process: Simulate generic signals
sSimulSig = bst_process('CallProcess', 'process_simulate_matrix', [], [], ...
    'subjectname', SubjectName, ...
    'condition',   'sub-01_ses-meg_task-facerecognition_run-01_proc-sss_meg_low', ...
    'samples',     1000, ...
    'srate',       1000, ...
    'matlab',      ['Data(1,:) = sin(2*pi*t);' 10 '']);
% Process: Simulate recordings from scouts
sSimulRec = bst_process('CallProcess', 'process_simulate_recordings', sSimulSig, [], ...
    'scouts',      {'Brodmann', {'V1 R'}}, ...
    'savesources', 1, ...
    'isnoise',     1, ...
    'noise1',      0.2, ...
    'noise2',      0);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sSimulRec, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 4, ...  % EEG
    'time',     0.25, ...
    'Comment',  'EEG simulated from Brodmann V1R');
% Process: Snapshot: Recordings topography (one time)
bst_process('CallProcess', 'process_snapshot', sSimulRec, [], ...
    'target',   6, ...  % Recordings topography (one time)
    'modality', 4, ...  % EEG
    'time',     0.25, ...
    'Comment',  'EEG simulated from Brodmann V1R');
% Process: Snapshot: Recordings topography (one time)
bst_process('CallProcess', 'process_snapshot', sSimulRec, [], ...
    'target',   6, ...  % Recordings topography (one time)
    'modality', 1, ...  % MEG (all)
    'time',     0.25, ...
    'Comment',  'MEG simulated from Brodmann V1R');


%% ===== 4. SINGLE AND DISTRIBUTION SOURCES =====
% === MEG NOISE COVARIANCE: EMPTY ROOM RECORDINGS ===
% Process: Create link to raw file 
sFilesNoise = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {NoiseFile, 'FIF'}, ...
    'channelreplace', 1, ...
    'channelalign',   0);
% Process: Low-pass:40Hz
sFilesNoiseClean = bst_process('CallProcess', 'process_bandpass', sFilesNoise, [], ...
    'sensortypes', 'MEG, EEG', ...
    'highpass',    0, ...
    'lowpass',     40, ...
    'tranband',    0, ...
    'attenuation', 'strict', ...  % 60dB
    'ver',         '2019', ...  % 2019
    'mirror',      0, ...
    'read_all',    0);
% Process: Compute noise covariance
bst_process('CallProcess', 'process_noisecov', sFilesNoiseClean, [], ...
    'baseline',    [], ...
    'sensortypes', 'MEG', ...
    'target',      1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',    1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',    0, ...
    'copycond',    1, ...
    'copysubj',    1, ...
    'copymatch',   1, ...
    'replacefile',    1);  % Replace

% === EEG NOISE COVARIANCE: PRE-STIM BASELINES ===
% Process: Compute covariance (noise or data)
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       [-0.5, -0.0009], ...
    'sensortypes',    'EEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    2);  % Merge

% === COMPUTE SOURCES: MEG ===
% Process: Compute sources [2018]
sFilesAvgSrc = bst_process('CallProcess', 'process_inverse_2018', sFilesAvg, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        'dSPM-unscaled: MEG ALL', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'dspm2018', ...
         'SourceOrient',   {{'fixed'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'reg', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'MEG GRAD', 'MEG MAG'}}));
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesAvgSrc(1), [], ...
    'target',         8, ...  % Sources (one time)
    'orient',         8, ...  % right_intern
    'time',           0.085, ...
    'threshold',      40, ...
    'Comment',        'Famous: MEG dSPM 85ms');
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesAvgSrc(1), [], ...
    'target',         8, ...  % Sources (one time)
    'orient',         6, ...  % back
    'time',           0.145, ...
    'threshold',      40, ...
    'Comment',        'Famous: MEG dSPM 145ms');
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesAvgSrc(1), [], ...
    'target',         8, ...  % Sources (one time)
    'orient',         4, ...  % bottom
    'time',           0.165, ...
    'threshold',      40, ...
    'Comment',        'Famous: MEG dSPM 165ms');

% === ROI ===
% Process: Scouts time series: V1 R
sFilesAvgScoutV1 = bst_process('CallProcess', 'process_extract_scout', sFilesAvgSrc, [], ...
    'timewindow',     [-0.5, 1.2], ...
    'scouts',         {'Brodmann-thresh', {'V1 R'}}, ...
    'scoutfunc',      1, ...  % Mean
    'isflip',         1, ...
    'isnorm',         0, ...
    'concatenate',    1, ...
    'save',           1, ...
    'addrowcomment',  1, ...
    'addfilecomment', 1);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvgScoutV1, [], ...
    'target',   5, ...  % Recordings time series
    'Comment',  'Right V1 time series');
% Process: Scouts time series: fusiform R
sFilesAvgScoutFusi = bst_process('CallProcess', 'process_extract_scout', sFilesAvgSrc, [], ...
    'timewindow',     [-0.5, 1.2], ...
    'scouts',         {'Desikan-Killiany', {'fusiform R'}}, ...
    'scoutfunc',      1, ...  % Mean
    'isflip',         1, ...
    'isnorm',         0, ...
    'concatenate',    1, ...
    'save',           1, ...
    'addrowcomment',  1, ...
    'addfilecomment', 1);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvgScoutFusi, [], ...
    'target',   5, ...  % Recordings time series
    'Comment',  'Right fusiform time series');

% === BEAMFORMING ===
% Process: Compute data covariance
bst_process('CallProcess', 'process_noisecov', sFilesEpochs, [], ...
    'baseline',       [-0.5, -0.001], ...
    'datatimewindow', [0.030, 0.300], ...
    'sensortypes',    'MEG, EEG', ...
    'target',         2, ...  % Data covariance      (covariance over data time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'copymatch',      0, ...
    'replacefile',    1);  % Replace
% Process: Compute sources [2018]
sFilesAvgBf = bst_process('CallProcess', 'process_inverse_2018', sFilesAvg, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        'PNAI: MEG ALL', ...
         'InverseMethod',  'lcmv', ...
         'InverseMeasure', 'nai', ...
         'SourceOrient',   {{'free'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'median', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'rms', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'MEG GRAD', 'MEG MAG'}}));
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesAvgBf(1), [], ...
    'target',         8, ...  % Sources (one time)
    'orient',         4, ...  % bottom
    'time',           0.165, ...
    'threshold',      0, ...
    'Comment',        'Famous: MEG LCMV 165ms');

% === DIPOLE SCANNING ===
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesAvg(1), [], ...
    'sourcespace', 2, ...  % MRI volume
    'volumegrid',  struct(...
         'Method',        'isotropic', ...
         'nLayers',       17, ...
         'Reduction',     3, ...
         'nVerticesInit', 4000, ...
         'Resolution',    0.005, ...
         'FileName',      []), ...
    'meg',         3, ...  % Overlapping spheres
    'eeg',         1);
% Process: Compute sources [2018]
sFilesAvgDip = bst_process('CallProcess', 'process_inverse_2018', sFilesAvg, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        'Dipoles: MEG ALL', ...
         'InverseMethod',  'gls', ...
         'InverseMeasure', 'performance', ...
         'SourceOrient',   {{'free'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'median', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'rms', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'MEG GRAD', 'MEG MAG'}}));
% Process: Dipole scanning
sFilesAvgDipScan = bst_process('CallProcess', 'process_dipole_scanning', sFilesAvgDip(1), [], ...
    'timewindow', [0.05, 0.3], ...
    'scouts',     {});
% Display dipoles
hFig = view_dipoles(sFilesAvgDipScan.FileName, 'mri3d');
panel_dipoles('SetGoodness', 0.5);
figure_3d('SetStandardView', hFig, 'back');
bst_report('Snapshot', hFig, sFilesAvgDipScan.FileName, 'Famous: dipoles goodness of fit>50% (50-300ms)', [200, 200, 640, 400]);
figure_3d('SetStandardView', hFig, 'right');
bst_report('Snapshot', hFig, sFilesAvgDipScan.FileName, 'Famous: dipoles goodness of fit>50% (50-300ms)', [200, 200, 640, 400]);
close(hFig);


%% ===== 5. GROUP ANALYSIS =====
% === PROJECT ON DEFAULT ANATOMY ===
% Process: Project on default anatomy: surface
sFilesAvgScrProj = bst_process('CallProcess', 'process_project_sources', sFilesAvgSrc(1), [], ...
    'headmodeltype', 'surface');  % Cortex surface
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesAvgScrProj(1), [], ...
    'target',         8, ...  % Sources (one time)
    'orient',         4, ...  % bottom
    'time',           0.165, ...
    'threshold',      40, ...
    'Comment',        'Famous: MEG dSPM 165ms projected on MNI template');

% === FACES vs SCRAMBLED, PARAMETRIC, SENSOR ===
% Process: Select file comments with tag: Scrambled
sFilesEpochsScrambled = bst_process('CallProcess', 'process_select_tag', sFilesEpochs, [], ...
    'tag',    'Scrambled', ...
    'search', 2, ...  % Search the file comments
    'select', 1);  % Select only the files with the tag
% Process: Ignore file comments with tag: Scrambled
sFilesEpochsFaces = bst_process('CallProcess', 'process_select_tag', sFilesEpochs, [], ...
    'tag',    'Scrambled', ...
    'search', 2, ...  % Search the file comments
    'select', 2);  % Ignore the files with the tag
% Process: t-test equal [0ms,500ms]          H0:(A=B), H1:(A<>B)
sFilesFacesScrm = bst_process('CallProcess', 'process_test_parametric2', sFilesEpochsFaces, sFilesEpochsScrambled, ...
    'timewindow',    [0, 0.5], ...
    'sensortypes',   '', ...
    'isabs',         0, ...
    'avgtime',       0, ...
    'avgrow',        0, ...
    'Comment',       '', ...
    'test_type',     'ttest_equal', ...  % Student's t-test   (equal variance)        A,B~N(m,v)t = (mean(A)-mean(B)) / (Sx * sqrt(1/nA + 1/nB))Sx = sqrt(((nA-1)*var(A) + (nB-1)*var(B)) / (nA+nB-2)) df = nA + nB - 2
    'tail',          'two');  % Two-tailed
% Set stat display
StatThreshOptions = bst_get('StatThreshOptions');
StatThreshOptions.pThreshold   = 0.01;
StatThreshOptions.durThreshold = 0;
StatThreshOptions.Correction   = 'fdr';
StatThreshOptions.Control      = [1 2 3];
bst_set('StatThreshOptions', StatThreshOptions);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesFacesScrm, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 4, ...  % EEG
    'time',     0.165, ...
    'Comment',  'Faces vs Scrambled: EEG, parametric t-test');
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesFacesScrm, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 1, ...  % MEG (all)
    'time',     0.165, ...
    'Comment',  'Faces vs Scrambled: MEG (all), parametric t-test');
% Process: Snapshot: Recordings topography (one time)
bst_process('CallProcess', 'process_snapshot', sFilesFacesScrm, [], ...
    'target',   6, ...  % Recordings topography (one time)
    'modality', 3, ...  % MEG MAG
    'time',     0.165, ...
    'Comment',  'Faces vs Scrambled: MEG (all) 165ms, parametric t-test');

% === FACES vs SCRAMBLED, CLUSTER, SENSOR ===
% Process: FT t-test unequal cluster [0ms,500ms MEG MAG]          H0:(A=B), H1:(A<>B)
sFilesFacesScrmClust = bst_process('CallProcess', 'process_ft_timelockstatistics', sFilesEpochsFaces, sFilesEpochsScrambled, ...
    'sensortypes',    'MEG MAG', ...
    'timewindow',     [0, 0.3], ...
    'isabs',          0, ...
    'avgtime',        0, ...
    'avgchan',        0, ...
    'randomizations', 1000, ...
    'statistictype',  1, ...  % Independent t-test
    'tail',           'two', ...  % Two-tailed
    'correctiontype', 2, ...  % cluster
    'minnbchan',      0, ...
    'clusteralpha',   0.05);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesFacesScrmClust, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 1, ...  % MEG (all)
    'time',     0.165, ...
    'Comment',  'Faces vs Scrambled: MEG (all), cluster');
% Process: Snapshot: Recordings topography (one time)
bst_process('CallProcess', 'process_snapshot', sFilesFacesScrmClust, [], ...
    'target',   6, ...  % Recordings topography (one time)
    'modality', 3, ...  % MEG MAG
    'time',     0.165, ...
    'Comment',  'Faces vs Scrambled: MEG (all) 165ms, cluster');

% === FACES vs SCRAMBLED, PERMUTATION, dSPM ===
% Process: Select results files in: sub-01/*/dSPM
sFilesEpochsSrc = bst_process('CallProcess', 'process_select_files_results', [], [], ...
    'subjectname',   SubjectName, ...
    'condition',     '', ...
    'tag',           'dSPM', ...
    'includebad',    0, ...
    'includeintra',  0, ...
    'includecommon', 0);
% Process: Select file names with tag: Scrambled_trial
sFilesEpochsSrcScrambled = bst_process('CallProcess', 'process_select_tag', sFilesEpochsSrc, [], ...
    'tag',    'Scrambled_trial', ...
    'search', 1, ...  % Search the file names
    'select', 1);  % Select only the files with the tag
% Process: Select file names with tag: Famous_trial
sFilesEpochsSrcFamous = bst_process('CallProcess', 'process_select_tag', sFilesEpochsSrc, [], ...
    'tag',    'Famous_trial', ...
    'search', 1, ...  % Search the file names
    'select', 1);  % Select only the files with the tag
% Process: Select file names with tag: Unfamiliar_trial
sFilesEpochsSrcUnfamiliar = bst_process('CallProcess', 'process_select_tag', sFilesEpochsSrc, [], ...
    'tag',    'Unfamiliar_trial', ...
    'search', 1, ...  % Search the file names
    'select', 1);  % Select only the files with the tag
% Process: Perm t-test equal [140ms,170ms]          H0:(A=B), H1:(A<>B)
sFilesFacesScrmSrc = bst_process('CallProcess', 'process_test_permutation2', [sFilesEpochsSrcFamous, sFilesEpochsSrcUnfamiliar], sFilesEpochsSrcScrambled, ...
    'timewindow',     [0.14, 0.17], ...
    'scoutsel',       {}, ...
    'scoutfunc',      1, ...  % Mean
    'isnorm',         0, ...
    'avgtime',        1, ...
    'iszerobad',      1, ...
    'Comment',        '', ...
    'test_type',      'ttest_equal', ...  % Student's t-test   (equal variance) t = (mean(A)-mean(B)) / (Sx * sqrt(1/nA + 1/nB))Sx = sqrt(((nA-1)*var(A) + (nB-1)*var(B)) / (nA+nB-2))
    'randomizations', 1000, ...
    'tail',           'two');  % Two-tailed
% Set colormap configuration
bst_colormaps('SetColormapAbsolute', 'stat2', '1');
bst_colormaps('SetColormapName', 'stat2', 'cmap_hot2');
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sFilesFacesScrmSrc, [], ...
    'target',         8, ...  % Sources (one time)
    'orient',         4, ...  % bottom
    'time',           0.165, ...
    'threshold',      0, ...
    'Comment',        'Faces vs Scrambled: MEG dSPM 165ms, permutation t-test');
% Reset colormap
bst_colormaps('RestoreDefaults', 'stat2');


%% ===== SAVE AND EXPORT REPORT ======
% Save report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, bst_fullfile(reports_dir, ['report_' ProtocolName '_' SubjectName '.html']));
end



