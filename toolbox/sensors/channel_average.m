function [MeanChannelMat, Message] = channel_average(ChannelMats, KeepCommon)
% CHANNEL_AVERAGE: Averages positions of MEG/EEG sensors.
%
% INPUT:
%     - ChannelMats : Cell array of channel.mat structures
%     - KeepCommon (default true) : if true, keep only channels that are
%       common between all files.
% OUPUT:
%     - MeanChannelMat : Average channel mat

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Francois Tadel, Marc Lalancette 2012-2019

% To do: average head point locations.

if nargin < 2 || isempty(KeepCommon)
    KeepCommon = true;
end

Message = [];

MeanChannelMat = ChannelMats{1};
nFiles = numel(ChannelMats);
MeanChannelMat.Projector(:) = []; % Keeps empty structure
MeanChannelMat = bst_history('reset', MeanChannelMat);
MeanChannelMat = bst_history('add',  MeanChannelMat,  'created', 'File created using channel_average');
if KeepCommon
    % Find common channels to all files.
    for i = 1:nFiles
        if i == 1
            CommonChans = {ChannelMats{i}.Channel.Name};
        else
            CommonChans = intersect(CommonChans, {ChannelMats{i}.Channel.Name}, 'stable');
        end
    end
    [Unused, iCommon, iChans] = intersect(CommonChans, {MeanChannelMat.Channel.Name}, 'stable'); % Stable keeps the order of CommonChans.
    % Update channel number in comment
    if numel(CommonChans) < numel(MeanChannelMat.Channel)
        iComment = find(MeanChannelMat.Comment == '(', 1, 'last');
        if ~isempty(iComment)
            MeanChannelMat.Comment(iComment:end) = '';
        end
        MeanChannelMat.Comment = sprintf('%s (%d)', MeanChannelMat.Comment, numel(CommonChans));
    end
    iMeg = find(strcmp({MeanChannelMat.Channel.Type}, 'MEG'));
    iRef = find(strcmp({MeanChannelMat.Channel.Type}, 'MEG REF'));
    if numel(iMeg) && numel(iRef) && isequal(size(MeanChannelMat.MegRefCoef), [numel(iMeg), numel(iRef)])
        MeanChannelMat.MegRefCoef(setdiff(iMeg, iChans), :) = [];
        % MegRefCoef might not be good if reference channels are different
        % between ChannelMats.  Give warning.
        iRemoveRefs = setdiff(iRef, iChans);
        if ~isempty(iRemoveRefs)
            Message = 'Some MEG reference channels removed; CTF compensation should probably not be changed using this common channel file.';
            MeanChannelMat.MegRefCoef(:, setdiff(iRef, iChans)) = [];
        end
    end
    MeanChannelMat.Channel = MeanChannelMat.Channel(:, iChans);
else
    CommonChans = {ChannelMats{1}.Channel.Name};
end
iMeg = find(strcmp({MeanChannelMat.Channel.Type}, 'MEG'));
iRef = find(strcmp({MeanChannelMat.Channel.Type}, 'MEG REF'));
iMegRef = sort([iMeg, iRef]);
nChan = numel(MeanChannelMat.Channel);

% For MEG, easier to average 'Dewar=>Native' transformation.  Applies
% directly to MEG and reference channels, all integration points.  Warn if
% missing or unusual transformations, but shouldn't happen.
if ~isempty(iMegRef)
    TransfMeg = zeros(4);
    nAvg = 0;
    isWarnTransfOrder = false;
    for i = 1:nFiles
        iTransf = find(strcmpi(ChannelMats{i}.TransfMegLabels, 'Dewar=>Native'), 1, 'first');
        if ~isempty(iTransf)
            if iTransf ~= 1
                isWarnTransfOrder = true;
            end
            TransfMeg = TransfMeg + ChannelMats{i}.TransfMeg{iTransf};
            nAvg = nAvg + 1;
        end
    end
    if isWarnTransfOrder
        if ~isempty(Message)
            Message = [Message, '\n'];
        end
        Message = [Message, 'Unexpected MEG transformation order; MEG channel positions may be wrong.'];
    end
    if nAvg < nFiles && ~isempty(Message)
        Message = [Message, '\n'];
    end
    if nAvg == 0
        % Not sure if this is possible, but would be ok if the channels are
        % still in dewar coordinates; no averaging required.
        Message = [Message, 'No Dewar=>Native transformation found; MEG channel positions not averaged.'];
        TransfMeg = eye(4);
    else
        if nAvg < nFiles
            Message = [Message, 'Missing Dewar=>Native transformations; MEG channel positions not fully averaged.'];
        end
        TransfMeg = TransfMeg ./ nAvg;
        iTransf = find(strcmpi(MeanChannelMat.TransfMegLabels, 'Dewar=>Native'), 1, 'first');
        if isempty(iTransf)
            OldTransf = eye(4);
            % Insert at first position, though this is unusual especially
            % if there are other transf.
            MeanChannelMat.TransfMegLabels = [{'Dewar=>Native'}, MeanChannelMat.TransfMegLabels];
            MeanChannelMat.TransfMeg = [{TransfMeg}, MeanChannelMat.TransfMeg];
            iTransf = 1;
        else
            OldTransf = MeanChannelMat.TransfMeg{iTransf};
            MeanChannelMat.TransfMeg{iTransf} = TransfMeg;
        end
        TransfMeg = TransfMeg / OldTransf;
        % Combine with all subsequent transf for applying later.
        for iTr = iTransf+1:numel(MeanChannelMat.TransfMeg)
            % Remove first (right), reapply last (left).
            TransfMeg = MeanChannelMat.TransfMeg{iTr} * TransfMeg / MeanChannelMat.TransfMeg{iTr};
        end
    end
    
    % Apply to channel locations and orientations.
    MeanChannelMat = channel_apply_transf(MeanChannelMat, TransfMeg, iMegRef, false);
    MeanChannelMat = MeanChannelMat{1};
    % Remove last tranformation we just added, it's already in the new 'Dewar=>Native'.
    MeanChannelMat.TransfMeg(end) = [];
    MeanChannelMat.TransfMegLabels(end) = [];
end

% For other channels, average positions and orientations.
nAvg = zeros(1, nChan);
% Check the consistency between all the channel files
for i = 2:nFiles
    % Check number of channels
    if ~KeepCommon && (length(ChannelMats{i}.Channel) ~= length(MeanChannelMat.Channel))
        Message = ['The channels files from the different studies do not have the same number of channels.' 10 ...
                   'Cannot create a common channel file.'];
        MeanChannelMat = [];
        return;
    end
    
    % Match channels by name.
    [Unused, iCommon, iChans] = intersect(CommonChans, {ChannelMats{i}.Channel.Name}, 'stable'); % Stable keeps the order of CommonChans.
    
    % Sum EEG channel locations
    for iChan = setdiff(1:nChan, iMegRef) % 1:nChan==iCommon because of stable
        % If the channel has no location in this file: skip
        if isempty(ChannelMats{i}.Channel(iChan).Loc)
            continue;
        % Check the size of Loc matrix and the values of Weights matrix
        elseif ~isempty(MeanChannelMat.Channel(iChan).Loc) && ~isequal(size(MeanChannelMat.Channel(iChan).Loc), size(ChannelMats{i}.Channel(iChans(iChan)).Loc))
            Message = ['The channels files from the different studies do not have the same structure.' 10 ...
                       'Cannot create a common channel file.'];
            MeanChannelMat = [];
            return;
        % Sum with existing average
        else
            MeanChannelMat.Channel(iChan).Loc    = MeanChannelMat.Channel(iChan).Loc    + ChannelMats{i}.Channel(iChans(iChan)).Loc;
            MeanChannelMat.Channel(iChan).Orient = MeanChannelMat.Channel(iChan).Orient + ChannelMats{i}.Channel(iChans(iChan)).Orient;
            nAvg(iChan) = nAvg(iChan) + 1;
        end
    end
end
% Divide the locations of channels by the number of channel files averaged.
% Orientations need to be normalized.
for iChan = 1:nChan
    if (nAvg(iChan) > 0)
        MeanChannelMat.Channel(iChan).Loc    = MeanChannelMat.Channel(iChan).Loc    / nAvg(iChan);
        MeanChannelMat.Channel(iChan).Orient = MeanChannelMat.Channel(iChan).Orient / norm(MeanChannelMat.Channel(iChan).Orient);
    end
end





