function tutorial_phantom_ctf(tutorial_dir)
% TUTORIAL_PHANTOM_CTF: Script that runs the tests for the CTF current phantom.
%
% CORRESPONDING ONLINE TUTORIAL:
%     https://neuroimage.usc.edu/brainstorm/Tutorials/PhantomCtf
%
% INPUTS: 
%     tutorial_dir: Directory where the sample_phantom.zip file has been unzipped

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
% Author: Francois Tadel, 2016


% ===== FILES TO IMPORT =====
% You have to specify the folder in which the tutorial dataset is unzipped
if (nargin == 0) || isempty(tutorial_dir) || ~file_exist(tutorial_dir)
    error('The first argument must be the full path to the dataset folder.');
end
% Build the path of the files to import
Run200FileDs  = fullfile(tutorial_dir, 'sample_phantom_ctf', 'ds',  'phantom_200uA_20150709_01.ds');
Run20FileDs   = fullfile(tutorial_dir, 'sample_phantom_ctf', 'ds',  'phantom_20uA_20150603_03.ds');
NoiseFileDs   = fullfile(tutorial_dir, 'sample_phantom_ctf', 'ds',  'emptyroom_20150709_01.ds');
Run200FileFif = fullfile(tutorial_dir, 'sample_phantom_ctf', 'fif', 'phantom_200uA_20150709_01.fif');
Run20FileFif  = fullfile(tutorial_dir, 'sample_phantom_ctf', 'fif', 'phantom_20uA_20150603_03.fif');
PosFile       = fullfile(tutorial_dir, 'sample_phantom_ctf', 'ds',  'phantom_20160222_01.pos');
% Check if the folder contains the required files
if ~file_exist(Run200FileDs)
    error(['The folder ' tutorial_dir ' does not contain the folder from the file sample_phantom_ctf.zip.']);
end

% ===== CREATE PROTOCOL =====
% The protocol name has to be a valid folder name (no spaces, no weird characters...)
ProtocolName = 'TutorialPhantom';
% Start brainstorm without the GUI
if ~brainstorm('status')
    brainstorm nogui
end
% Delete existing protocol
gui_brainstorm('DeleteProtocol', ProtocolName);
% Create new protocol
gui_brainstorm('CreateProtocol', ProtocolName, 0, 0);
% Start a new report
bst_report('Start');


% ===== ANATOMY =====
% Subject name
SubjectNameDs = 'PhantomCTF-ds';
SubjectNameFif = 'PhantomCTF-fif';
% Generate the phantom anatomy
generate_phantom_ctf(SubjectNameDs);
generate_phantom_ctf(SubjectNameFif);

% ===== LINK CONTINUOUS FILES =====
% Process: Create link to raw files
sFilesRun200Ds = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectNameDs, ...
    'datafile',     {Run200FileDs, 'CTF'}, ...
    'channelalign', 0);
sFilesRun20Ds = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectNameDs, ...
    'datafile',     {Run20FileDs, 'CTF'}, ...
    'channelalign', 0);
sFilesNoiseDs = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectNameDs, ...
    'datafile',     {NoiseFileDs, 'CTF'}, ...
    'channelalign', 0);
sFilesRun200Fif = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectNameFif, ...
    'datafile',     {Run200FileFif, 'FIF'}, ...
    'channelalign', 0);
sFilesRun20Fif = bst_process('CallProcess', 'process_import_data_raw', [], [], ...
    'subjectname',  SubjectNameFif, ...
    'datafile',     {Run20FileFif, 'FIF'}, ...
    'channelalign', 0);
sFilesRawDs  = [sFilesRun200Ds, sFilesRun20Ds];
sFilesRawFif = [sFilesRun200Fif, sFilesRun20Fif];
sFilesRawAll = [sFilesRawDs, sFilesRawFif];

% Process: Convert to continuous (CTF): Continuous
bst_process('CallProcess', 'process_ctf_convert', [sFilesRawDs, sFilesNoiseDs], [], ...
    'rectype', 2);  % Continuous


% ===== ADD HEAD POINTS =====
% Process: Add head points
bst_process('CallProcess', 'process_headpoints_add', sFilesRawAll, [], ...
    'channelfile', {PosFile, 'ASCII_NXYZ'});

% Process: Snapshot: Sensors/MRI registration
bst_process('CallProcess', 'process_snapshot', [sFilesRun200Ds, sFilesRun20Ds], [], ...
    'target',   1, ...  % Sensors/MRI registration
    'modality', 1, ...  % MEG (All)
    'orient',   1, ...  % left
    'Comment',  'MEG/MRI Registration');


% ===== DETECT EVENTS =====
% Process: Detect: stim
bst_process('CallProcess', 'process_evt_detect_threshold', sFilesRawAll, [], ...
    'eventname',    'stim', ...
    'channelname',  'HDAC006', ...
    'timewindow',   [0, 99.99833333], ...
    'thresholdMAX', 0.5, ...
    'units',        1, ...  % None (10^0)
    'bandpass',     [], ...
    'isAbsolute',   0, ...
    'isDCremove',   1);
% Process: Convert to simple event
bst_process('CallProcess', 'process_evt_simple', sFilesRawAll, [], ...
    'eventname', 'stim', ...
    'method',    2);  % Keep the middle of the events


% ===== IMPORT EVENTS =====
% Process: Import MEG/EEG: Events
sFilesEpochsAll = bst_process('CallProcess', 'process_import_data_event', sFilesRawAll, [], ...
    'subjectname', [], ...
    'condition',   [], ...
    'eventname',   'stim', ...
    'timewindow',  [0, 10], ...
    'epochtime',   [-0.07, 0.07], ...
    'createcond',  0, ...
    'ignoreshort', 1, ...
    'usectfcomp',  1, ...
    'usessp',      1, ...
    'freq',        [], ...
    'baseline',    [-0.07, 0.07]);    % Remove DC: Entire file 
% Process: Average: By folder (subject average)
sAvgAll = bst_process('CallProcess', 'process_average', sFilesEpochsAll, [], ...
    'avgtype',    3, ...  % By folder (subject average)
    'avg_func',   1, ...  % Arithmetic average:  mean(x)
    'weighted',   0, ...
    'keepevents', 0);

% Process: Snapshot: Recordings time series
bst_process('CallProcess', 'process_snapshot', sAvgAll, [], ...
    'target',   5, ...  % Recordings time series
    'modality', 1);     % MEG (All)
% Process: Snapshot: Recordings topography (one time)
bst_process('CallProcess', 'process_snapshot', sAvgAll, [], ...
    'target',   6, ...  % Recordings topography (one time)
    'modality', 1, ...  % MEG (All)
    'time',     0);


% ===== NOISE COVARIANCE =====
% Process: Compute noise covariance
bst_process('CallProcess', 'process_noisecov', sFilesNoiseDs, [], ...
    'baseline',    [], ...
    'sensortypes', 'MEG, EEG, SEEG, ECOG', ...
    'target',      1, ...  % Noise covariance
    'dcoffset',    1, ...  % Block by block, to avoid effects of slow shifts in data
    'identity',    0, ...
    'copycond',    1, ...
    'copysubj',    1, ...
    'replacefile', 1);  % Replace
% Process: Snapshot: Noise covariance
bst_process('CallProcess', 'process_snapshot', sFilesNoiseDs, [], ...
    'target',  3, ...  % Noise covariance
    'Comment', 'Noise covariance');


% ===== SOURCE ESTIMATION =====
% Define source grid options
VolumeGrid = struct(...
    'Method',       'isotropic', ...
    'nLayers',       17, ...
    'Reduction',     3, ...
    'nVerticesInit', 4000, ...
    'Resolution',    0.005);
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sAvgAll, [], ...
    'Comment',     '', ...
    'sourcespace', 2, ...  % MRI volume
    'volumegrid',  VolumeGrid, ...
    'meg',         2);  % Single sphere
% Define inverse options
InverseOptions = struct(...
    'Comment',        'Dipoles: Single sphere', ...
    'InverseMethod',  'gls', ...
    'InverseMeasure', 'performance', ...
    'SourceOrient',   {{'free'}}, ...
    'Loose',          0.2, ...
    'UseDepth',       1, ...
    'WeightExp',      0.5, ...
    'WeightLimit',    10, ...
    'NoiseMethod',    'reg', ...
    'NoiseReg',       0.1, ...
    'SnrMethod',      'fixed', ...
    'SnrRms',         0.001, ...
    'SnrFixed',       3, ...
    'ComputeKernel',  1, ...
    'DataTypes',      {{'MEG'}});
% Process: Compute sources [2018]
sAvgSrcAll = bst_process('CallProcess', 'process_inverse_2018', sAvgAll, [], ...
    'output',  2, ...  % Kernel only: one per file
    'inverse', InverseOptions);
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sAvgSrcAll, [], ...
    'target',    8, ...  % Sources (one time)
    'orient',    6, ...  % back
    'time',      0, ...
    'threshold', 40);


% ===== DIPOLE SCANNING =====
% Process: Dipole scanning
sDipScan = bst_process('CallProcess', 'process_dipole_scanning', sAvgSrcAll, [], ...
    'timewindow', [0, 0], ...
    'scouts', {});
% Process: Snapshot: Dipoles
bst_process('CallProcess', 'process_snapshot', sDipScan, [], ...
    'target',   13, ...  % Dipoles
    'orient',   3);      % top


% ===== FIELDTRIP DIPOLE FITTING =====
% Process: FieldTrip: ft_dipolefitting
sDipFit = bst_process('CallProcess', 'process_ft_dipolefitting', sAvgAll, [], ...
    'filetag',     'Single sphere', ...
    'timewindow',  [0, 0], ...
    'sensortypes', 'MEG', ...
    'dipolemodel', 1, ...  % Moving dipole
    'numdipoles',  1, ...
    'symmetry',    0);
% Process: Snapshot: Dipoles
bst_process('CallProcess', 'process_snapshot', sDipFit, [], ...
    'target',   13, ...  % Dipoles
    'orient',   3); % top


% ===== REPORT RESULTS: SINGLE SPHERE =====
strResults = ['CTF current phantom' 10 '==============================================' 10];
% Dipole scanning
strResults = [strResults, 'Single sphere / Scanning:' 10];
for i = 1:length(sDipScan)
    dipMat = load(file_fullpath(sDipScan(i).FileName));
    strResults = [strResults, sprintf(' - %s:  [%1.2f, %1.2f, %1.2f]mm   %1.2f%% gof\n', bst_fileparts(sDipScan(i).FileName), dipMat.Dipole(1).Loc.*1000, dipMat.Dipole(1).Goodness.*100)];
end
% Dipole fitting
strResults = [strResults, 'Single sphere / Fitting:' 10];
for i = 1:length(sDipFit)
    dipMat = load(file_fullpath(sDipFit(i).FileName));
    strResults = [strResults, sprintf(' - %s:  [%1.2f, %1.2f, %1.2f]mm   %1.2f%% gof\n', bst_fileparts(sDipFit(i).FileName), dipMat.Dipole(1).Loc.*1000, dipMat.Dipole(1).Goodness.*100)];
end
% Report results
bst_report('Info', 'process_dipole_scanning', [], strResults);
disp([10 '==============================================' 10 strResults]);


% ===== OVERLAPPING SPHERES =====
% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sAvgAll, [], ...
    'Comment',     '', ...
    'sourcespace', 2, ...  % MRI volume
    'volumegrid',  VolumeGrid, ...
    'meg',         3);  % Overlapping spheres
% Process: Compute sources [2018]
InverseOptions.Comment = 'Dipoles: Overlapping spheres';
sSrcOs = bst_process('CallProcess', 'process_inverse_2018', sAvgAll, [], ...
    'output',  2, ...  % Kernel only: one per file
    'inverse', InverseOptions);
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sSrcOs, [], ...
    'target',    8, ...  % Sources (one time)
    'orient',    6, ...  % back
    'time',      0, ...
    'threshold', 40);

% Process: Dipole scanning
sDipScanOs = bst_process('CallProcess', 'process_dipole_scanning', sSrcOs, [], ...
    'timewindow', [0, 0], ...
    'scouts', {});
% Process: FieldTrip: ft_dipolefitting
sDipFitOs = bst_process('CallProcess', 'process_ft_dipolefitting', sAvgAll, [], ...
    'filetag',     'Overlapping spheres', ...
    'timewindow',  [0, 0], ...
    'sensortypes', 'MEG', ...
    'dipolemodel', 1, ...  % Moving dipole
    'numdipoles',  1, ...
    'symmetry',    0);


% ===== OVERLAPPING SPHERES: REPORT RESULTS =====
strResults = '';
% Dipole scanning
strResults = [strResults, 'Overlapping spheres / Scanning:' 10];
for i = 1:length(sDipScanOs)
    dipMat = load(file_fullpath(sDipScanOs(i).FileName));
    strResults = [strResults, sprintf(' - %s:  [%1.2f, %1.2f, %1.2f]mm   %1.2f%% gof\n', bst_fileparts(sDipScanOs(i).FileName), dipMat.Dipole(1).Loc.*1000, dipMat.Dipole(1).Goodness.*100)];
end
% Dipole fitting
strResults = [strResults, 'Overlapping spheres / Fitting:' 10];
for i = 1:length(sDipFitOs)
    dipMat = load(file_fullpath(sDipFitOs(i).FileName));
    strResults = [strResults, sprintf(' - %s:  [%1.2f, %1.2f, %1.2f]mm   %1.2f%% gof\n', bst_fileparts(sDipFitOs(i).FileName), dipMat.Dipole(1).Loc.*1000, dipMat.Dipole(1).Goodness.*100)];
end
% Report results
bst_report('Info', 'process_dipole_scanning', [], strResults);
disp(strResults);


% ===== OPENMEEG BEM =====
% Process: Generate BEM surfaces (DS)
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectNameDs, ...
    'nscalp',      362, ...
    'nouter',      162, ...
    'ninner',      162, ...
    'thickness',   4);
% Process: Generate BEM surfaces (FIF)
bst_process('CallProcess', 'process_generate_bem', [], [], ...
    'subjectname', SubjectNameFif, ...
    'nscalp',      362, ...
    'nouter',      162, ...
    'ninner',      162, ...
    'thickness',   4);

% Process: Compute head model
bst_process('CallProcess', 'process_headmodel', sAvgAll, [], ...
    'Comment',     '', ...
    'sourcespace', 2, ...  % MRI volume
    'volumegrid',  VolumeGrid, ...
    'meg',         4);  % OpenMEEG BEM
% Process: Compute sources [2018]
InverseOptions.Comment = 'Dipoles: OpenMEEG BEM';
sSrcBem = bst_process('CallProcess', 'process_inverse_2018', sAvgAll, [], ...
    'output',  2, ...  % Kernel only: one per file
    'inverse', InverseOptions);
% Process: Snapshot: Sources (one time)
bst_process('CallProcess', 'process_snapshot', sSrcBem, [], ...
    'target',    8, ...  % Sources (one time)
    'orient',    6, ...  % back
    'time',      0, ...
    'threshold', 40);
% Process: Dipole scanning
sDipScanBem = bst_process('CallProcess', 'process_dipole_scanning', sSrcBem, [], ...
    'timewindow', [0, 0], ...
    'scouts', {});


% ===== OPENMEEG BEM: REPORT RESULTS =====
strResults = '';
% Dipole scanning
strResults = [strResults, 'OpenMEEG BEM / Scanning:' 10];
for i = 1:length(sDipScanBem)
    dipMat = load(file_fullpath(sDipScanBem(i).FileName));
    strResults = [strResults, sprintf(' - %s:  [%1.2f, %1.2f, %1.2f]mm   %1.2f%% gof\n', bst_fileparts(sDipScanBem(i).FileName), dipMat.Dipole(1).Loc.*1000, dipMat.Dipole(1).Goodness.*100)];
end
% Report results
bst_report('Info', 'process_dipole_scanning', [], strResults);
disp(strResults);



% Save and display report
ReportFile = bst_report('Save', []);
bst_report('Open', ReportFile);


