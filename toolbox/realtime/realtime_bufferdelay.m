% This file can be used in finding the delay of a realtime processing
% system. It repeatedly sends trigger codes of value 1 to a parallel port
% and then reads from the Fieldtrip buffer until that trigger is detected,
% then sending code 2 on the parallel port.
%
% 2012, 2018-08-08, 2021-10-25

% To try next:
% - smaller buffer size (e.g. 10 ms, 5 ms)
% - lower sampling rate (possibly greater Acq delays?)
% - linux priority for running buffer

%% Testing options
WhereBuffer = 'acq'; %'mex' 'exe' 'acq'
RaisePriority = false;
% if RaisePriority is true, Psychtoolbox must be installed. But this may not be
% necessary.  If it is not installed, download and run SetupPsychtoolbox.
BlockSize = 80;
SamplingRate = 4000; % Set at aquisition
UseWaitDat = true;

%% Load Fieldtrip in Brainstorm (Plugins menu) and add buffer mex folder, or just this:
addpath 'C:\Toolboxes\fieldtrip-20211020';
ft_defaults
addpath 'C:\Toolboxes\fieldtrip-20211020\realtime\src\buffer\matlab';

% if getting the error: "Buffer size N must be an integer-valued scalar double."
% it's because it's using Matlab's buffer function instead of the mex file. it
% should probably be renamed ft_buffer or rt_buffer...

%% Initialize the Fieldtrip buffer (if running locally)
switch(lower(WhereBuffer))
    case 'mex'
        host = 'localhost';
        buffer('tcpserver', 'init', host, port);
    case 'exe'
        host = 'localhost';
    case 'acq'
        host = '10.0.0.2';       % IP address of host computer
    otherwise
        error('Unknown buffer location.');
end
port = 1972;

%% Then start ctf2ft_v3 and acquisition on Acq.


%% Initialize io64 parallel port driver. 
% Its mex file must be on the path

% *** Initialize the low_latency parallel port driver *** %
ioObj = io64;               % Create a parallel port handle
status = io64(ioObj);       % If this returns '0' the port driver is loaded & ready
% Find this address in Device Manager.
LPT1=hex2dec('3000');        %'378' is the default address of LPT1 in hex
%LPT3=hex2dec('DC98'); %LPT3 out to BNC break-out box on stim PC
% Use once to "warm up".
io64(ioObj,LPT1,255);
io64(ioObj,LPT1,0);


%% *** Read the event of trigger and send an echo *** %
% We now want to read the STIM REF channel at which the trigger arrives
% and then send an echo (a trigger of different value) to the same channel,
% so we can subsequently calculate the delay from the recorded data.

% cfg.channel = 'UPPT002'; % this is the channel that we will be reading from
StimChannel = 'UPPT002'; % this is the channel that we will be reading from

global RTConfig;
RTConfig = struct(...
    'FThost',           [], ...     % fieldtrip host address
    'FTport',           [], ...     % fieldtrip port number
    'ChunkSamples',     [], ...     % number of samples in each data chunk from ACQ
    'nChunks',          0, ...      % number of chunks to collect for each processing block
    'BlockSamples',     0, ...      % minimum number of samples per processing block
    'SampRate',         [], ...     % sampling rate
    'MegRefCoef',       [], ...     % third gradiant coefficients
    'ChannelGains',     [], ...     % channel gains to be applied to buffer data
    'iStim',            [], ...     % indices of stim channels
    'iMEG',             [], ...     % indices of MEG channels
    'iMEGREF',          [], ...     % indices of MEG ref channels
    'iHeadLocChan',     [], ...     % indices of head localization channels
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
% RTConfig = panel_realtime('GetTemplate');
RTConfig.FThost = host;
RTConfig.FTport = port;
RTConfig.BlockSamples = BlockSize;
RTConfig.prevSample = 0;

% *** set trigger codes *** %
tr_write = 1;
tr_read = 2;
trigDuration = 0.5;         % Duration between each trigger (in seconds)
% Make pulse duration extremely short so as to not affect delay calculation.
pulseDuration = 0.0001;  % Duration of each pulse (in seconds)
nTrig = 120;             % Number of triggers (trials)
timeout = 2000;  % get data request timeout, in ms

%%
if RaisePriority
    Priority(1); %#ok<*UNRCH> %raise priority for stimulus presentation
    pause(1);
end

% Determine number of samples in each data chuck sent by Acq.
hdr = buffer('get_hdr', [], host, port);
iStimChan = find(strcmpi(hdr.channel_names, StimChannel));
if isempty(iStimChan)
    error('Parallel port channel not found in buffer data.');
end
RTConfig.SampRate = hdr.fsample;
RTConfig.prevSample = hdr.nsamples;
% Try without a timeout.
if UseWaitDat
    hdr = buffer('wait_dat', [RTConfig.prevSample + 1, 0, inf], host, port);
else
    while hdr.nsamples == RTConfig.prevSample
        hdr = buffer('get_hdr', [], host, port);
    end
end

RTConfig.prevSample = hdr.nsamples;
RTConfig.ChunkSamples = hdr.nsamples - nSamples;

% "Warm up" other functions.
tic;
DataMat = GetNextDataBuffer(host, port, timeout, iStimChan);
toc

%%
t_read=zeros(nTrig,1);
for n = 1:nTrig
    % Set current (previous) sample before trigger: we don't need to check all
    % the data since last trigger was detected.
    %     DataMat = GetNextDataBuffer(host, port, timeout);
    hdr = buffer('wait_dat', [0, 0, 5000], host, port);
    RTConfig.prevSample = hdr.nsamples;
    
    %send a pulse lasting 'stimduration' to LPT1
    io64(ioObj, LPT1, tr_write);
    % For correct delay estimation, we need to start counting immediately after
    % trigger is sent, same as for "toc" below.
    tic;
    % If the pulse duration was significant, we would need to do the first data
    % check before the pause.
    pause(pulseDuration)
    io64(ioObj, LPT1, 0);
    
    %     DataMat = GetNextDataBuffer(host, port, timeout);
    %     while isempty(DataMat) || ~any(DataMat(iStimChan,:) == tr_write)
    %         DataMat = GetNextDataBuffer(host, port, timeout);
    %     end
    DataMat = GetNextDataBuffer(host, port, timeout, iStimChan);
    while isempty(DataMat) || ~any(DataMat == tr_write)
        DataMat = GetNextDataBuffer(host, port, timeout, iStimChan);
    end
    % We got the signal.
    t_read(n)=toc;
    io64(ioObj, LPT1, tr_read);
    pause(pulseDuration)
    io64(ioObj, LPT1, 0);
    pause(trigDuration)
end

if RaisePriority
    Priority(0); %drop priority back to normal
end

% Results
% plot(t_read(1:end), '.')
hist(t_read);

%% This now works with buffer running externally
clear buffer
