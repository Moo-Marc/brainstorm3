function tutorial_epilepsy(tutorial_dir, reports_dir)
% TUTORIAL_EPILEPSY: Script that reproduces the results of the online tutorial "EEG/Epilepsy".
%
% CORRESPONDING ONLINE TUTORIALS:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/Epilepsy
%
% INPUTS: 
%    - tutorial_dir: Directory where the sample_epilepsy.zip file has been unzipped
%    - reports_dir  : Directory where to save the execution report (instead of displaying it)

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
% Author: Francois Tadel, 2014-2018


% ===== FILES TO IMPORT =====
% Output folder for reports
if (nargin < 2) || isempty(reports_dir) || ~isdir(reports_dir)
    reports_dir = [];
end
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the tutorial dataset folder.');
end
% Build the path of the files to import
AnatDir   = fullfile(tutorial_dir, 'sample_epilepsy', 'anatomy');
RawFile   = fullfile(tutorial_dir, 'sample_epilepsy', 'data', 'tutorial_eeg.bin');
ElcFile   = fullfile(tutorial_dir, 'sample_epilepsy', 'data', 'tutorial_electrodes.elc');
SpikeFile = fullfile(tutorial_dir, 'sample_epilepsy', 'data', 'tutorial_spikes.txt');
% Check if the folder contains the required files
if ~file_exist(RawFile)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_epilepsy.zip.']);
end
% Subject name
SubjectName = 'sepi01';


% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialEpilepsy';
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 1);
% Start a new report
bst_report('Start');


% ===== IMPORT ANATOMY =====
% Process: Import anatomy folder
bst_process('CallProcess', 'process_import_anatomy', [], [], ...
    'subjectname', SubjectName, ...
    'mrifile',     {AnatDir, 'FreeSurfer'}, ...
    'nvertices',   15000, ...
    'nas', [134, 222,  74], ...
    'lpa', [ 58, 123,  69], ...
    'rpa', [204, 120,  75]);


% ===== ACCESS THE RECORDINGS =====
% Process: Create link to raw file
sFilesRaw = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',    SubjectName, ...
    'datafile',       {RawFile, 'EEG-DELTAMED'}, ...
    'channelreplace', 1, ...
    'channelalign',   0);

% Process: Add EEG positions
bst_process('CallProcess', 'process_channel_addloc', sFilesRaw, [], ...
    'channelfile', {ElcFile, 'XENSOR'}, ...
    'usedefault',  1, ...
    'fixunits',    1, ...
    'vox2ras',     0);
% Process: Refine registration
bst_process('CallProcess', 'process_headpoints_refine', sFilesRaw, []);
% Process: Project electrodes on scalp
bst_process('CallProcess', 'process_channel_project', sFilesRaw, []);

% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', sFilesRaw, [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 4, ...  % EEG
    'orient',   1, ...  % left
    'Comment',  'MEG/MRI Registration');


% ===== EVENTS: SPIKES AND HEARTBEATS =====
% Process: Detect heartbeats
bst_process('CallProcess', 'process_evt_detect_ecg', sFilesRaw, [], ...
    'channelname', 'ECG', ...
    'timewindow',  [], ...
    'eventname',   'cardiac');
% Process: Events: Import from file
bst_process('CallProcess', 'process_evt_import', sFilesRaw, [], ...
    'evtfile', {SpikeFile, 'ARRAY-TIMES'}, ...
    'evtname', 'SPIKE');


% ===== PRE-PROCESSING =====
% Process: Power spectrum density (Welch)
sFilesPsd = bst_process('CallProcess', 'process_psd', sFilesRaw, [], ...
    'timewindow',  [], ...
    'win_length',  10, ...
    'win_overlap', 50, ...
    'sensortypes', 'EEG', ...
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
    'target',   10, ...  % Frequency spectrum
    'Comment',  'Power spectrum density');

% Process: Band-pass:0.5-80Hz
sFilesRaw = bst_process('CallProcess', 'process_bandpass', sFilesRaw, [], ...
    'sensortypes', 'EEG', ...
    'highpass',    0.5, ...
    'lowpass',     80, ...
    'attenuation', 'strict', ...  % 60dB
    'mirror',      0);

% Process: Re-reference EEG
bst_process('CallProcess', 'process_eegref', sFilesRaw, [], ...
    'eegref',      'AVERAGE', ...
    'sensortypes', 'EEG');

% Process: Power spectrum density (Welch)
sFilesPsdClean = bst_process('CallProcess', 'process_psd', sFilesRaw, [], ...
    'timewindow',  [], ...
    'win_length',  10, ...
    'win_overlap', 50, ...
    'sensortypes', 'EEG', ...
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
    'Comment',  'Power spectrum density');


% ===== ICA =====
% Process: ICA components: Infomax
bst_process('CallProcess', 'process_ica', sFilesRaw, [], ...
    'timewindow',   [500, 700], ...
    'eventname',    '', ...
    'eventtime',    [-0.1992, 0.1992], ...
    'bandpass',     [0, 0], ...
    'nicacomp',     24, ...
    'sensortypes',  'EEG', ...
    'usessp',       1, ...
    'ignorebad',    1, ...
    'saveerp',      0, ...
    'method',       1, ...  % Infomax:    EEGLAB / RunICA
    'select',       [1 2]); % Force the selection: components #1 and #2


% ===== IMPORT RECORDINGS =====
% Process: Import MEG/EEG: Events
sFilesEpochs = bst_process('CallProcess', 'process_import_data_event', sFilesRaw, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'eventname',   'SPIKE', ...
    'timewindow',  [], ...
    'epochtime',   [-0.3, 0.5], ...
    'createcond',  1, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        [], ...
    'baseline',    []);
        
% Process: Average: By condition (subject average)
sFilesAvg = bst_process('CallProcess', 'process_average', sFilesEpochs, [], ...
    'avgtype',    3, ...
    'avg_func',   1, ...  % Arithmetic average: mean(x)
    'weighted',   0, ...
    'keepevents', 0);

% Configure the display so that the negative values points up
bst_set('FlipYAxis', 1);
% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 4, ...  % EEG
    'Comment',  'Average spike');
% Process: Snapshot: Recordings topography (contact sheet)
bst_process('CallProcess', 'process_snapshot', sFilesAvg, [], ...
    'target',   7, ...  % Recordings topography (contact sheet)
    'modality', 4, ...  % EEG
    'contact_time',   [-0.040, 0.110], ...
    'contact_nimage', 16, ...
    'Comment',  'Average spike');


% ===== SOURCE ANALYSIS: SURFACE =====
% Process: Generate BEM surfaces
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectName, ...
    'nscalp',      642, ...
    'nouter',      482, ...
    'ninner',      482, ...
    'thickness',   4);
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesAvg, [], ...
    'sourcespace', 1, ...  % Cortex surface
    'eeg',         3, ...  % OpenMEEG BEM
    'openmeeg',    struct(...
         'BemSelect',    [0, 0, 1], ...
         'BemCond',      [1, 0.0125, 1], ...
         'BemNames',     {{'Scalp', 'Skull', 'Brain'}}, ...
         'BemFiles',     {{}}, ...
         'isAdjoint',    0, ...
         'isAdaptative', 1, ...
         'isSplit',      0, ...
         'SplitLength',  4000));

% Process: Compute noise covariance
bst_process('CallProcess', 'process_noisecov', sFilesRaw, [], ...
    'baseline',       [110, 160], ...
    'sensortypes',    'EEG', ...
    'target',         1, ...  % Noise covariance     (covariance over baseline time window)
    'dcoffset',       1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',       0, ...
    'copycond',       0, ...
    'copysubj',       0, ...
    'replacefile',    1);  % Replace

% Process: Compute sources [2018]
sAvgSrc = bst_process('CallProcess', 'process_inverse_2018', sFilesAvg, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        'sLORETA: EEG', ...
         'InverseMethod',  'minnorm', ...
         'InverseMeasure', 'sloreta', ...
         'SourceOrient',   {{'free'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       0, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'reg', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'fixed', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'EEG'}}));
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sAvgSrc, [], ...
    'target',    8, ...  % Sources (one time)
    'modality',  1, ...  % MEG (All)
    'orient',    3, ...  % top
    'time',      0, ...
    'threshold', 60, ...
    'Comment',   'Average spike');


% ===== SOURCE ANALYSIS: VOLUME =====
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sFilesAvg, [], ...
    'sourcespace', 2, ...  % MRI volume
    'volumegrid',  struct(...
         'Method',        'adaptive', ...
         'nLayers',       17, ...
         'Reduction',     3, ...
         'nVerticesInit', 4000, ...
         'Resolution',    0.005, ...
         'FileName',      []), ...
    'eeg',         2);     % 3-shell sphere

% Process: Compute sources [2018]
sAvgSrcVol = bst_process('CallProcess', 'process_inverse_2018', sFilesAvg, [], ...
    'output',  1, ...  % Kernel only: shared
    'inverse', struct(...
         'Comment',        'Dipoles: EEG', ...
         'InverseMethod',  'gls', ...
         'InverseMeasure', 'performance', ...
         'SourceOrient',   {{'free'}}, ...
         'Loose',          0.2, ...
         'UseDepth',       1, ...
         'WeightExp',      0.5, ...
         'WeightLimit',    10, ...
         'NoiseMethod',    'reg', ...
         'NoiseReg',       0.1, ...
         'SnrMethod',      'rms', ...
         'SnrRms',         1e-06, ...
         'SnrFixed',       3, ...
         'ComputeKernel',  1, ...
         'DataTypes',      {{'EEG'}}));
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sAvgSrcVol, [], ...
    'target',    8, ...  % Sources (one time)
    'modality',  1, ...  % MEG (All)
    'orient',    3, ...  % top
    'time',      0, ...
    'threshold', 0, ...
    'Comment',   'Dipole modeling');

% Process: Dipole scanning
sDipScan = bst_process('CallProcess', 'process_dipole_scanning', sAvgSrcVol, [], ...
    'timewindow', [-0.040, 0.100], ...
    'scouts',     {});
% Process: Snapshot: Dipoles
bst_process('CallProcess', 'process_snapshot', sDipScan, [], ...
    'target',    13, ...  % Dipoles
    'orient',    3, ...   % top
    'threshold', 90, ...
    'Comment',   'Dipole scanning');
% Process: Snapshot: Dipoles
bst_process('CallProcess', 'process_snapshot', sDipScan, [], ...
    'target',    13, ...  % Dipoles
    'orient',    1, ...   % left
    'threshold', 90, ...
    'Comment',   'Dipole scanning');

% Process: FieldTrip: ft_dipolefitting
sDipFit = bst_process('CallProcess', 'process_ft_dipolefitting', sFilesAvg, [], ...
    'timewindow',  [-0.040, 0.100], ...
    'sensortypes', 'EEG', ...
    'dipolemodel', 1, ...  % Moving dipole
    'numdipoles',  1, ...
    'volumegrid',  [], ...
    'symmetry',    0, ...
    'filetag',     '');
% Process: Snapshot: Dipoles
bst_process('CallProcess', 'process_snapshot', sDipFit, [], ...
    'target',    13, ...  % Dipoles
    'orient',    3, ...   % top
    'threshold', 95, ...
    'Comment',   'Dipole fitting');
% Process: Snapshot: Dipoles
bst_process('CallProcess', 'process_snapshot', sDipFit, [], ...
    'target',    13, ...  % Dipoles
    'orient',    1, ...   % left
    'threshold', 95, ...
    'Comment',   'Dipole fitting');


% ===== TIME-FREQUENCY =====
% Process: Import MEG/EEG: Time
sRawImport = bst_process('CallProcess', 'process_import_data_time', sFilesRaw, [], ...
    'subjectname', SubjectName, ...
    'condition',   '', ...
    'timewindow',  [1890, 1900], ...
    'split',       0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1);
% Process: Time-frequency (Morlet wavelets)
sRawTf = bst_process('CallProcess', 'process_timefreq', sRawImport, [], ...
    'sensortypes', 'EEG', ...
    'edit',        struct(...
         'Comment',         'Power,2-80Hz', ...
         'TimeBands',       [], ...
         'Freqs',           [2, 2.5, 3.1, 3.7, 4.3, 5, 5.7, 6.4, 7.2, 8.1, 9, 9.9, 10.9, 12, 13.1, 14.3, 15.6, 17, 18.4, 19.9, 21.6, 23.3, 25.1, 27, 29.1, 31.3, 33.6, 36, 38.6, 41.4, 44.3, 47.4, 50.7, 54.1, 57.8, 61.8, 65.9, 70.3, 75, 80], ...
         'MorletFc',        1, ...
         'MorletFwhmTc',    3, ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'all', ...
         'SaveKernel',      0), ...
    'normalize',   'multiply');  % 1/f compensation: Multiply output values by frequency
% Process: Snapshot: Time-frequency maps
bst_process('CallProcess', 'process_snapshot', sRawTf, [], ...
    'target',  14, ...  % Time-frequency maps
    'rowname', 'FC1');

% Process: Time-frequency (Morlet wavelets)
sAvgTf = bst_process('CallProcess', 'process_timefreq', sFilesEpochs, [], ...
    'sensortypes', 'EEG', ...
    'edit',        struct(...
         'Comment',         'Avg,Power,2-80Hz', ...
         'TimeBands',       [], ...
         'Freqs',           [2, 2.5, 3.1, 3.7, 4.3, 5, 5.7, 6.4, 7.2, 8.1, 9, 9.9, 10.9, 12, 13.1, 14.3, 15.6, 17, 18.4, 19.9, 21.6, 23.3, 25.1, 27, 29.1, 31.3, 33.6, 36, 38.6, 41.4, 44.3, 47.4, 50.7, 54.1, 57.8, 61.8, 65.9, 70.3, 75, 80], ...
         'MorletFc',        1, ...
         'MorletFwhmTc',    3, ...
         'ClusterFuncTime', 'none', ...
         'Measure',         'power', ...
         'Output',          'average', ...
         'RemoveEvoked',    0, ...
         'SaveKernel',      0), ...
    'normalize',   'none');  % None: Save non-standardized time-frequency maps
% Process: Event-related perturbation (ERS/ERD): [-199ms,-102ms]
sAvgTfNorm = bst_process('CallProcess', 'process_baseline_norm', sAvgTf, [], ...
    'baseline',  [-0.200, -0.100], ...
    'method',    'ersd', ...  % Event-related perturbation (ERS/ERD):    x_std = (x - &mu;) / &mu; * 100
    'overwrite', 0);
% Process: Snapshot: Time-frequency maps
bst_process('CallProcess', 'process_snapshot', sAvgTfNorm, [], ...
    'target',  14, ...  % Time-frequency maps
    'rowname', 'FC1');


% Save and display report
ReportFile = bst_report('Save', []);
if ~isempty(reports_dir) && ~isempty(ReportFile)
    bst_report('Export', ReportFile, reports_dir);
else
    bst_report('Open', ReportFile);
end

disp([10 'BST> tutorial_epilepsy: Done.' 10]);

