function varargout = process_fooof(varargin)
% PROCESS_FOOOF: Applies the "Fitting Oscillations and One Over F" algorithm on a Welch's PSD
%
% REFERENCE: Please cite the original algorithm:
%    Donoghue T, Haller M, Peterson E, Varma P, Sebastian P, Gao R, Noto T,
%    Lara AH, Wallis JD, Knight RT, Shestyuk A, Voytek B. Parameterizing 
%    neural power spectra into periodic and aperiodic components. 
%    Nature Neuroscience (in press)

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
% Authors: Luc Wilson, Francois Tadel, 2020

eval(macro_method);
end


%% ===== GET DESCRIPTION =====
function sProcess = GetDescription() %#ok<DEFNU>
    % Description the process
    sProcess.Comment     = 'FOOOF: Fitting oscillations and 1/f';
    sProcess.Category    = 'Custom';
    sProcess.SubGroup    = 'Frequency';
    sProcess.Index       = 503;
    sProcess.Description = 'https://neuroimage.usc.edu/brainstorm/Tutorials/Fooof';
    % Definition of the input accepted by this process
    sProcess.InputTypes  = {'timefreq'};
    sProcess.OutputTypes = {'timefreq'};
    sProcess.nInputs     = 1;
    sProcess.nMinFiles   = 1;
    sProcess.isSeparator = 1;
    % Definition of the options
    % === FOOOF TYPE
    sProcess.options.implementation.Comment = {'Matlab', 'Python 3 (3.7 recommended)', 'FOOOF implementation:'; 
                                               'matlab', 'python', ''};
    sProcess.options.implementation.Type    = 'radio_linelabel';
    sProcess.options.implementation.Value   = 'matlab';
    sProcess.options.implementation.Controller.matlab = 'Matlab';
    sProcess.options.implementation.Controller.python = 'Python';
    % === FREQUENCY RANGE
    sProcess.options.freqrange.Comment = 'Frequency range for analysis: ';
    sProcess.options.freqrange.Type    = 'freqrange_static';   % 'freqrange'
    sProcess.options.freqrange.Value   = {[1 40], 'Hz', 1};
    % === APERIODIC MODE 
    sProcess.options.apermode.Comment = {'Fixed', 'Ceiling', 'Floor', 'Full', 'Aperiodic mode (default=fixed):'; ...
                                         'fixed', 'ceiling', 'floor', 'full', ''};
    sProcess.options.apermode.Type    = 'radio_linelabel';
    sProcess.options.apermode.Value   = 'fixed';
    % === PEAK TYPE
    sProcess.options.peaktype.Comment = {'Gaussian', 'Cauchy*', 'Best of both* (* experimental)', 'Peak model:'; ...
                                         'gaussian', 'cauchy', 'best', ''};
    sProcess.options.peaktype.Type    = 'radio_linelabel';
    sProcess.options.peaktype.Value   = 'gaussian';
    sProcess.options.peaktype.Class   = 'Matlab';
    % === MAX PEAKS
    sProcess.options.maxpeaks.Comment = 'Maximum number of peaks (default=3): ';
    sProcess.options.maxpeaks.Type    = 'value';
    sProcess.options.maxpeaks.Value   = {3, '', 0};
    % === Peak constraints
    sProcess.options.peakconstraints.Comment = {'Unconstrained', 'Weak guess weight + reject', 'Strong guess weight + reject', 'Constrained (optim toolbox)', 'Peak fit constraints:'; ...
                                                'none', 'weak', 'strong', 'constrained', ''};
    sProcess.options.peakconstraints.Type    = 'radio_linelabel';
    sProcess.options.peakconstraints.Value   = 'constrained';
    sProcess.options.peakconstraints.Class   = 'Matlab';
    % === PEAK WIDTH LIMITS
    sProcess.options.peakwidth.Comment = 'Peak width limits (default=[0.5-12]): ';
    sProcess.options.peakwidth.Type    = 'freqrange_static';
    sProcess.options.peakwidth.Value   = {[0.5 12], 'Hz', 1};
    % === MIN PEAK HEIGHT
    sProcess.options.minpeakheight.Comment = 'Minimum peak height (default=3): ';
    sProcess.options.minpeakheight.Type    = 'value';
    sProcess.options.minpeakheight.Value   = {3, 'dB', 1};
    % === PROXIMITY THRESHOLD
    sProcess.options.proxthresh.Comment = 'Proximity threshold (default=2): ';
    sProcess.options.proxthresh.Type    = 'value';
    sProcess.options.proxthresh.Value   = {2, 'stdev of peak model', 1};
    sProcess.options.proxthresh.Class   = 'Matlab';
    % Fitting error scale
    sProcess.options.errorscale.Comment = {'Log', 'Linear', 'Fitting error scale:'; ...
                                           'log', 'lin', ''};
    sProcess.options.errorscale.Type    = 'radio_linelabel';
    sProcess.options.errorscale.Value   = 'log';
    sProcess.options.errorscale.Class   = 'Matlab';
    % Final fit
    sProcess.options.finalfit.Comment = {'Aperiodic', 'Full model', 'Final fit parameters:'; ...
                                         'background', 'full', ''};
    sProcess.options.finalfit.Type    = 'radio_linelabel';
    sProcess.options.finalfit.Value   = 'background';
    sProcess.options.finalfit.Class   = 'Matlab';
    
    % === SORT PEAKS TYPE
    sProcess.options.sorttype.Comment = {'Peak parameters', 'Frequency bands', 'Sort peaks using:'; ...
                                         'param', 'band', ''};
    sProcess.options.sorttype.Type    = 'radio_linelabel';
    sProcess.options.sorttype.Value   = 'param';
    sProcess.options.sorttype.Controller.param = 'Param';
    sProcess.options.sorttype.Controller.band = 'Band';
    sProcess.options.sorttype.Group   = 'output';
    % === SORT PEAKS PARAM
    sProcess.options.sortparam.Comment = {'Frequency', 'Amplitude', 'Std dev.', 'Sort by peak...'; ...
                                          'frequency', 'amplitude', 'std', ''};
    sProcess.options.sortparam.Type    = 'radio_linelabel';
    sProcess.options.sortparam.Value   = 'frequency';
    sProcess.options.sortparam.Class   = 'Param';
    sProcess.options.sortparam.Group   = 'output';
    % === SORT FREQ BANDS
    DefaultFreqBands = bst_get('DefaultFreqBands');
    sProcess.options.sortbands.Comment = '';
    sProcess.options.sortbands.Type    = 'groupbands';
    sProcess.options.sortbands.Value   = DefaultFreqBands(:,1:2);
    sProcess.options.sortbands.Class   = 'Band';
    sProcess.options.sortbands.Group   = 'output';
end


%% ===== FORMAT COMMENT =====
function Comment = FormatComment(sProcess) %#ok<DEFNU>
    Comment = sProcess.Comment;
end


%% ===== RUN =====
function OutputFile = Run(sProcess, sInputs) %#ok<DEFNU>
    % Initialize returned list of files
    OutputFile = {};
    
    % Fetch user settings
    implementation = sProcess.options.implementation.Value;
    opt.freq_range          = sProcess.options.freqrange.Value{1};
    opt.peak_width_limits   = sProcess.options.peakwidth.Value{1};
    opt.max_peaks           = sProcess.options.maxpeaks.Value{1};
    opt.min_peak_height     = sProcess.options.minpeakheight.Value{1} / 10; % convert from dB to B
    opt.aperiodic_mode      = sProcess.options.apermode.Value;
    opt.peak_threshold      = 2;   % 2 std dev: parameter for interface simplification
    % Matlab-only options
    opt.peak_type           = sProcess.options.peaktype.Value;
    opt.proximity_threshold = sProcess.options.proxthresh.Value{1};
    opt.constraint          = sProcess.options.peakconstraints.Value;
    opt.log_error           = isequal(sProcess.options.errorscale.Value, 'log');
    opt.final_fit           = sProcess.options.finalfit.Value;
    %opt.reject_peaks        = ismember(opt.constraint, {'weak', 'strong'});   % Threshold after fitting always selected for Matlab (mirrors the Python FOOOF closest by removing peaks that do not satisfy a user's predetermined conditions)
    % Python-only options
    opt.verbose    = false;
    % Output options
    opt.sort_type  = sProcess.options.sorttype.Value;
    opt.sort_param = sProcess.options.sortparam.Value;
	opt.sort_bands = sProcess.options.sortbands.Value;

    % Check input frequency bounds
    if (any(opt.freq_range < 0) || opt.freq_range(1) >= opt.freq_range(2))
        bst_report('error','Invalid Frequency range');
        return
    end
    
    % Initialize returned list of files
    OutputFile = cell(1, length(sInputs));
    for iFile = 1:length(sInputs)
        bst_progress('text',['Standby: FOOOFing spectrum ' num2str(iFile) ' of ' num2str(length(sInputs))]);
        % Load input file
        PsdMat = in_bst_timefreq(sInputs(iFile).FileName);
        % Exclude 0Hz from the computation
        if (opt.freq_range(1) == 0) && (PsdMat.Freqs(1) == 0) && (length(PsdMat.Freqs) >= 2)
            opt.freq_range(1) = PsdMat.Freqs(2);
        end
        
        % === COMPUTE FOOOF MODEL ===
        % Switch between implementations
        switch (implementation)
            case 'matlab'   % Matlab standalone FOOOF
                if strcmp(opt.constraint, 'constrained') && ~(exist('fmincon', 'file') == 2)
                    bst_error('Constrained fit requires Matlab optimisation toolbox.');
                    return;
                end                
                [FOOOF_freqs, FOOOF_data] = FOOOF_matlab(PsdMat.TF, PsdMat.Freqs, opt);  
            case 'python'
                opt.peak_type = 'gaussian';
                [FOOOF_freqs, FOOOF_data] = process_fooof_py('FOOOF_python', PsdMat.TF, PsdMat.Freqs, opt);
                % Remove unnecessary structure level, allowing easy concatenation across channels, e.g. for display.
                FOOOF_data = FOOOF_data.FOOOF;
            otherwise
                error('Invalid implentation.');
        end

        % === FOOOF ANALYSIS ===
        if isequal(implementation, 'matlab') && isequal(opt.aperiodic_mode, 'floor')
            isFloor = true;
        else
            isFloor = false;
        end
        TFfooof = PsdMat.TF(:,1,ismember(PsdMat.Freqs,FOOOF_freqs));
        [ePeaks, eAperiodics, eStats] = FOOOF_analysis(FOOOF_data, PsdMat.RowNames, TFfooof, ...
            opt.sort_type, opt.sort_param, opt.sort_bands, isFloor, isequal(implementation, 'matlab')); 
        
        % === PREPARE OUTPUT STRUCTURE ===
        % Create file structure
        PsdMat.Options.FOOOF = struct(...
            'options',    opt, ...
            'freqs',      FOOOF_freqs, ...
            'data',       FOOOF_data, ...
            'peaks',      ePeaks, ...
            'aperiodics', eAperiodics, ...
            'stats',      eStats);
        % Comment: Add FOOOF
        if ~isempty(strfind(PsdMat.Comment, 'PSD:'))
            PsdMat.Comment = strrep(PsdMat.Comment, 'PSD:', 'FOOOF:');
        else
            PsdMat.Comment = strcat(PsdMat.Comment, ' | FOOOF');
        end
        % History: Computation
        PsdMat = bst_history('add', PsdMat, 'compute', 'FOOOF');
        
        % === SAVE FILE ===
        % Filename: add _fooof tag
        [fPath, fName, fExt] = bst_fileparts(file_fullpath(sInputs(iFile).FileName));
        NewFile = file_unique(bst_fullfile(fPath, [fName, '_fooof', fExt]));
        % Save file
        bst_save(NewFile, PsdMat, 'v6');
        % Add file to database structure
        db_add_data(sInputs(iFile).iStudy, NewFile, PsdMat);
        % Return new file
        OutputFile{iFile} = NewFile;
    end
end


%% ===================================================================================
%  ===== MATLAB FOOOF ================================================================
%  ===================================================================================

%% ===== MATLAB STANDALONE FOOOF =====
function [fs, fg] = FOOOF_matlab(TF, Freqs, opt)
    % Find all frequency values within user limits
    fMask = (bst_round(Freqs,1) >= opt.freq_range(1)) & (Freqs <= opt.freq_range(2));
    fs = Freqs(fMask);
    spec = log10(squeeze(TF(:,1,fMask))); % extract log spectra
    nChan = size(TF,1);
    if nChan == 1, spec = spec'; end
    % Initalize FOOOF structs
    fg(nChan) = struct(...
            'aperiodic_params', [],...
            'init_ap_params',   [],...
            'robust_ap_params', [],...
            'peak_params',      [],...
            'peak_types',       '',...
            'ap_fit',           [],...
            'ap_mask',          [],...
            'init_ap_fit',      [],...
            'robust_ap_fit',    [],...
            'fooofed_spectrum', [],...
            'peak_fit',         [],...
            'error',            [],...
            'r_squared',        []);
    isFloor = isequal(opt.aperiodic_mode, 'floor');
    % Iterate across channels
    for iChan = 1:nChan
        bst_progress('set', bst_round(iChan / nChan,2) * 100);
        % Fit aperiodic robustly, trying to ignore parts of the spectrum belonging to peaks.
        [robust_ap_params, aperiodic_mask, init_ap_params] = fit_aperiodic(fs, spec(iChan,:), opt.aperiodic_mode, true, opt.log_error);
        % Remove aperiodic
        flat_spec = spec(iChan,:) - expo_function(fs, robust_ap_params, isFloor);
        % Fit peaks, and remove those that don't satisfy requirements
        [peak_pars, peak_function] = fit_peaks(fs, flat_spec, opt.max_peaks, opt.peak_threshold, opt.min_peak_height, ...
            opt.peak_width_limits/2, opt.proximity_threshold, opt.peak_type, opt.constraint, opt.log_error);
        % Final fit
        switch opt.final_fit
            case 'background'
                % Refit aperiodic
                aperiodic_spec = spec(iChan,:);
                for iPeak = 1:size(peak_pars,1)
                    aperiodic_spec = aperiodic_spec - peak_function(fs,peak_pars(iPeak,1), peak_pars(iPeak,2), peak_pars(iPeak,3));
                end
                aperiodic_pars = fit_aperiodic(fs, aperiodic_spec, opt.aperiodic_mode, false, opt.log_error);
            case 'full'
                % Refit entire model at once
                [aperiodic_pars, peak_pars] = fit_full(fs, spec(iChan,:), opt, robust_ap_params, peak_pars, peak_function);
                % Not rejecting peaks again (for now)
        end
        % Generate model fit
        ap_fit = expo_function(fs, aperiodic_pars, isFloor);
        model_fit = ap_fit;
        for iPeak = 1:size(peak_pars,1)
            model_fit = model_fit + peak_function(fs, peak_pars(iPeak,1), peak_pars(iPeak,2), peak_pars(iPeak,3));
        end
        % Calculate model error
        if opt.log_error
            MSE = mean((spec(iChan,:) - model_fit).^2);
            rsq_tmp = corrcoef(spec(iChan,:),model_fit).^2;
        else
            MSE = mean((10.^spec(iChan,:) - 10.^model_fit).^2);
            rsq_tmp = corrcoef(10.^spec(iChan,:), 10.^model_fit).^2;
        end
        % Return FOOOF results
        fg(iChan).aperiodic_params = aperiodic_pars;
        fg(iChan).init_ap_params   = init_ap_params;
        fg(iChan).robust_ap_params = robust_ap_params;
        fg(iChan).peak_params      = peak_pars;
        fg(iChan).peak_types       = func2str(peak_function);
        fg(iChan).ap_fit           = 10.^ap_fit;
        fg(iChan).ap_mask          = aperiodic_mask;
        fg(iChan).init_ap_fit      = 10.^expo_function(fs, init_ap_params, isFloor);
        fg(iChan).robust_ap_fit    = 10.^expo_function(fs, robust_ap_params, isFloor);
        fg(iChan).fooofed_spectrum = 10.^model_fit;
        fg(iChan).peak_fit         = 10.^(model_fit-ap_fit); 
        fg(iChan).error            = MSE;
        fg(iChan).r_squared        = rsq_tmp(2);
        %plot(fs', [fg(chan).ap_fit', (10.^model_fit - 10.^ap_fit)', fg(chan).fooofed_spectrum'])
    end
end


%% ===== CORE MODELS =====
function ys = gaussian(freqs, mu, hgt, sigma)
%       Gaussian function to use for fitting.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency vector to create gaussian fit for.
%       mu, hgt, sigma : doubles
%           Parameters that define gaussian function (centre frequency,
%           height, and standard deviation).
%
%       Returns
%       -------
%       ys :    1xn array
%       Output values for gaussian function.

    ys = hgt*exp(-(((freqs-mu)./sigma).^2) /2);

end

function ys = cauchy(freqs, ctr, hgt, gam)
%       Cauchy function to use for fitting.
% 
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency vector to create cauchy fit for.
%       ctr, hgt, gam : doubles
%           Parameters that define cauchy function (centre frequency,
%           height, and "standard deviation" [gamma]).
%
%       Returns
%       -------
%       ys :    1xn array
%       Output values for cauchy function.

    ys = hgt./(1+((freqs-ctr)/gam).^2);

end

function logy = expo_function(freqs, params, isFloor)
%       Exponential function to use for fitting spectrum background.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Input frequency values.
%       params : 1xm array (slope, intercept, ceiling, floor)
%           Parameters (a,b,c,f) that define the functions:
%           logy = a * log10(x) + b
%           logy = b - log10(x.^-a + 10^c)
%           logy = b - log10(1./(x.^a + 10^f) + 10^c)
%              or if isFloor is true
%           logy = b + log10(x.^a + 10^c)
%
%       Returns
%       -------
%       ys :    1xn array
%           Output values for exponential function.

    if nargin < 3 || isempty(isFloor)
        isFloor = false;
    end
    if numel(params) < 4
        % Add possibly absent ceiling and floor parameters.
        % As defined, these last 2 parameters are powers of 10 relative to b,
        % with the ceiling sign flipped for convenience.
        params = [params, -inf, -inf];
    end
    if isFloor 
        % Put floor and (-inf) ceiling parameters in their spot.
        params([3,4]) = params([4,3]);
    end
    logy = params(2) - log10(1./(freqs.^params(1) + 10^params(4)) + 10^params(3));

end


%% ===== FITTING ALGORITHM =====
function [aperiodic_params, perc_mask, initial_params] = fit_aperiodic(freqs, spect, aperiodic_mode, isRobust, isLogError)
%       Fit the aperiodic component of the power spectrum.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       spectrum : 1xn array
%           Power values, in log10 scale.
%       aperiodic_mode : {'fixed','ceiling'}
%           Defines absence or presence of ceiling in aperiodic component.
%
%       Returns
%       -------
%       aperiodic_params : 1xn array
%           Parameter estimates for aperiodic fit.

    if nargin < 5 || isempty(isLogError)
        isLogError = false;
    end
    
    if nargin < 4 || isempty(isRobust)
        isRobust = false;
    end

    isFloor = false;
    switch (aperiodic_mode)
        case 'fixed' % linear in log-log
            guess_params = [-2, spect(1)];
        case 'ceiling'  % with ceiling at low frequencies
            guess_params = [-2, spect(1), -1];
        case 'full' % also with noise floor at high frequencies
            guess_params = [-2, spect(1), -1, -2];
        case 'floor' % no ceiling
            guess_params = [-2, spect(1), -2];
            isFloor = true;
    end
    % Set initial guess params for background fit
    % Cost function relative tolerance.
    RelFunTol = 1e-5;
    StartingError = error_ap_function(guess_params, freqs, spect);
    AbsFunTol = StartingError * RelFunTol;
    options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', AbsFunTol, ...
        'MaxFunEvals', 5000, 'MaxIter', 5000);

    aperiodic_params = fminsearch(@error_ap_function, guess_params, options, freqs, spect);
    
    if nargout > 2
        initial_params = aperiodic_params;
    end
    if isRobust
        % Use the parameters found with the whole spectrum to define a frequency mask and fit again.
        % Flatten spectrum based on initial aperiodic fit
        flatspec = spect - expo_function(freqs, aperiodic_params, isFloor);
        % Flatten outliers - any points that drop below 0
        flatspec(flatspec(:) < 0) = 0;
        % Use percentile threshold, in terms of # of points, to extract and re-fit
        perc_mask = flatspec <= bst_prctile(flatspec, 2.5);
        
        % Second aperiodic fit - using results of first fit as guess parameters
        aperiodic_params = fminsearch(@error_ap_function, aperiodic_params, options, freqs(perc_mask), spect(perc_mask));
    end
    
    %% ===== Background ERROR FUNCTIONS =====
    function err = error_ap_function(params, xs, ys)
        ym = expo_function(xs, params, isFloor);
        if isLogError
            err = sum((ys - ym).^2);
        else
            err = sum((10.^ys - 10.^ym).^2);
        end
    end
    
end

function [best_params, best_function] = fit_peaks(freqs, flat_spec, max_n_peaks, peak_threshold, ...
        min_peak_height, width_limits, proxThresh, peakType, constraint, isLogError)
%       Iteratively fit peaks to flattened spectrum.
%
%       Parameters
%       ----------
%       freqs : 1xn array
%           Frequency values for the power spectrum, in linear scale.
%       flat_iter : 1xn array
%           Flattened (aperiodic removed) power spectrum.
%       max_n_peaks : double
%           Maximum number of gaussians to fit within the spectrum.
%       peak_threshold : double
%           Threshold (in standard deviations of noise floor) to detect a peak.
%       min_peak_height : double
%           Minimum height of a peak (in log10).
%       gauss_std_limits : 1x2 double
%           Limits to gaussian (cauchy) standard deviation (gamma) when detecting a peak.
%       proxThresh : double
%           Minimum distance between two peaks, in st. dev. (gamma) of peaks.
%       peakType : {'gaussian', 'cauchy', 'both'}
%           Which types of peaks are being fitted
%       constraint : {'none', 'weak', 'strong', 'constrained'}
%           Parameter to weigh initial estimates during optimization (Weak,
%           or Strong), or constrained optimization with Matlab Optimization Toolbox.
%
%       Returns
%       -------
%       gaussian_params : mx3 array, where m = No. of peaks.
%           Parameters that define the peak fit(s). Each row is a peak, as [mean, height, st. dev. (gamma)].

    if isequal(peakType, 'best')
        peakType = {@gaussian, @cauchy};
    else
        peakType = {str2func(peakType)};
    end
    best_error = inf;
    
    % Cost function relative tolerance.
    RelFunTol = 1e-5;

    for peak_function = peakType
        peak_function = peak_function{1};  %#ok<FXSET>
        % Start with intact flat_spectrum
        flat_iter = flat_spec;
        
        % Initialize matrix of guess parameters for peak function fitting.
        guess = zeros(max_n_peaks, 3);
        % Find peak: Loop through, finding a candidate peak, and fitting with a guess peak function.
        % Stopping procedure based on either the limit on # of peaks,
        % or the relative or absolute height thresholds.
        for iPeak = 1:max_n_peaks
            % Find candidate peak - the maximum point of the flattened spectrum.
            [guess_height, iMaxHeight] = max(flat_iter);
                        
            % Set the guess parameters for fitting - mean and height.
            guess_freq = freqs(iMaxHeight);
            
            % Data-driven first guess at standard deviation
            % Find half height index on each side of the center frequency.
            half_height = 0.5 * guess_height;
            
            iLeft = sum(flat_iter(1:iMaxHeight) <= half_height);
            iRight = length(flat_iter) - sum(flat_iter(iMaxHeight:end) <= half_height);
            
            % Keep bandwidth estimation from the shortest side.
            % We grab shortest to avoid estimating very large std from overalapping peaks.
            % Grab the shortest side, ignoring a side if the half max was not found.
            % Note: will fail if both iLeft & iRight end up as None (probably shouldn't happen).
            short_side = min(abs([iLeft,iRight]-iMaxHeight));
            
            % Estimate width from FWHM. Calculate FWHM, converting to Hz, get guess std from FWHM
            fwhm = short_side * 2 * (freqs(2)-freqs(1));
            guess_width = fwhm / (2 * sqrt(2 * log(2)));
            
            % Check that guess width isn't outside preset limits; restrict if so.
            % Note: without this, fmincon fails if given guess outside bounds.
            if guess_width < width_limits(1)
                guess_width = width_limits(1);
            elseif guess_width > width_limits(2)
                guess_width = width_limits(2);
            end
            
            % Subtract best-guess peak.
            flat_iter = flat_iter - peak_function(freqs, guess_freq, guess_height, guess_width);
            
            % Stop searching for peaks if height is small compared to
            % relative (remaining noise + peaks std) or absolute thresholds.
            if guess_height <= peak_threshold * std(flat_iter) || guess_height <= min_peak_height
                break
            end
            
            % Collect guess parameters.
            guess(iPeak,:) = [guess_freq, guess_height, guess_width];
        end
        % Remove unused guesses
        guess(guess(:,1) == 0,:) = [];

        if ~isequal(lower(constraint), 'none')
            % Check peaks based on height, edges, and on overlap
            % Drop any that violate requirements.
            guess(guess(:,2) < min_peak_height,:) = []; % remove peaks shorter than limit
            guess = drop_peak_overlap(guess, proxThresh, [min(freqs) max(freqs)]);
        end
        
        % If there are peak guesses, fit the peaks.
        % Fit group of peak guesses with a fit function.
        if ~isempty(guess)
            nPeaks = size(guess, 1);
            switch lower(constraint)
                case 'constrained'
                    % Use fmincon from Optimisation Toolbox                    
                    % fmincon stops when *any* tolerance is satisfied.
                    % The tolerance values are *relative* for the default algorithm (interior-point).
                    options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', RelFunTol, ...
                        'MaxFunEvals', 3000, 'MaxIter', 3000); % Tuned options
                    % Bounds: center freq, height, width
                    lb = [max(guess(:,1)-guess(:,3) * 2, freqs(1)), zeros(nPeaks,1), ones(nPeaks,1) * width_limits(1)];
                    ub = [min(guess(:,1)+guess(:,3) * 2, freqs(end)), inf(nPeaks,1), ones(nPeaks,1) * width_limits(2)];
                    peak_params = fmincon(@error_peaks, guess, [],[],[],[], ...
                        lb, ub, [], options, freqs, flat_spec);
                    error = error_peaks(peak_params, freqs, flat_spec);
                otherwise
                    % Use basic simplex approach, fminsearch, with cost function based on parameter guesses.
                    % fminsearch stops when *both* tolx and tolfun are satisfied.
                    % The tolerance values are *absolute*.
                    % Find approximate absolute cost function tolerance.
                    StartingError = error_peaks(guess, freqs, flat_spec);
                    AbsFunTol = StartingError * RelFunTol;
                    options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', AbsFunTol, ...
                        'MaxFunEvals', 5000, 'MaxIter', 5000);
                    peak_params = fminsearch(@error_peaks, guess, options, freqs, flat_spec);
                    error = error_peaks(peak_params, freqs, flat_spec);
            end
            % Reject peaks to enforce some limits.
            if ismember(lower(constraint), {'weak', 'strong'})
                peak_params(peak_params(:,3) < width_limits(1), :) = []; % remove peaks narrower than limit
                peak_params(peak_params(:,3) > width_limits(2), :) = []; % remove peaks broader than limit
            end
            if ~isequal(lower(constraint), 'none')
                peak_params(peak_params(:,2) < min_peak_height,:)     = []; % remove peaks shorter than limit
                peak_params = drop_peak_overlap(peak_params, proxThresh, [min(freqs) max(freqs)]); % remove smallest of two peaks fit too closely
            end
        else
            peak_params = zeros(0, 3);
            error = sum(flat_spec.^2);
        end
        
        if error < best_error
            best_error = error;
            best_params = peak_params;
            best_function = peak_function;
        end
    end

    %% ===== Peak ERROR FUNCTION =====
    function err = error_peaks(params, xVals, yVals)
        fitted_vals = zeros(size(yVals));
        weak = 1e2;
        strong = 1e7;
        for iPeako = 1:size(params,1)
            fitted_vals = fitted_vals + peak_function(xVals, params(iPeako,1), params(iPeako,2), params(iPeako,3));
        end
        % Subtract the peak model from the spectrum.
        % Sum of square residuals
        if isLogError
            err = sum((yVals - fitted_vals).^2);
        else
            err = sum((10.^yVals - 10.^fitted_vals).^2);
        end
        switch constraint
            % case {'none', 'constrained'} % do nothing.
            case 'weak' % Add small weight to deviations from guess m and amp
                err = err + ...
                    weak*sum((params(:,1)-guess(:,1)).^2) + ...
                    weak*sum((params(:,2)-guess(:,2)).^2);
            case 'strong' % Add large weight to deviations from guess m and amp
                err = err + ...
                    strong*sum((params(:,1)-guess(:,1)).^2) + ...
                    strong*sum((params(:,2)-guess(:,2)).^2);
        end
    end
        
end

% Fit the full model (scale-free background + oscillation peaks) at once.
function [ap_params, peak_params] = fit_full(freqs, spect, opt, ap_params, peak_params, peak_function)

    % Options used in error function
    isLogError = opt.log_error;
    Constraint = opt.constraint;
    isFloor = isequal(opt.aperiodic_mode, 'floor');
    
    % Pack parameters
    nApParams = numel(ap_params);
    nPeaks = size(peak_params, 1);
    StartingParams = [ap_params(:); peak_params(:)];
    
    % Cost function relative tolerance.
    RelFunTol = 1e-5;
    
    switch lower(opt.constraint)
        case 'constrained'
            % Use fmincon from Optimisation Toolbox
            % fmincon stops when *any* tolerance is satisfied.
            % The tolerance values are *relative* for the default algorithm (interior-point).
            options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', RelFunTol, ...
                'MaxFunEvals', 3000, 'MaxIter', 3000); % Tuned options
            % Peak bounds
            lb = [max(peak_params(:,1)-peak_params(:,3) * 2, freqs(1)), zeros(nPeaks,1), ones(nPeaks,1) * opt.peak_width_limits(1)/2];
            ub = [min(peak_params(:,1)+peak_params(:,3) * 2, freqs(end)), inf(nPeaks,1), ones(nPeaks,1) * opt.peak_width_limits(2)/2];
            % Add bounds for ap parameters.
            lb = [-inf(nApParams,1); lb(:)];
            ub = [inf(nApParams,1); ub(:)];
            model_params = fmincon(@error_full, StartingParams, [],[],[],[], ...
                lb, ub, [], options, freqs, spect);
        otherwise
            % Use basic simplex approach, fminsearch, with cost function based on parameter guesses.
            % fminsearch stops when *both* tolx and tolfun are satisfied.
            % The tolerance values are *absolute*.
            % Find approximate absolute cost function tolerance.
            StartingError = error_full(StartingParams, freqs, spect);
            AbsFunTol = StartingError * RelFunTol;
            options = optimset('Display', 'off', 'TolX', 1e-4, 'TolFun', AbsFunTol, ...
                'MaxFunEvals', 5000, 'MaxIter', 5000);
            model_params = fminsearch(@error_full, StartingParams, options, freqs, spect);
    end
    %error = error_full(model_params, freqs, spect);
    
    % Unpack parameters
    ap_params = model_params(1:nApParams(1))';
    peak_params = reshape(model_params((nApParams(1)+1):end), [], 3);

    %% ===== Full model error function =====
    function err = error_full(Params, Freq, Spec)

        % Unpack parameters
        ap_ps = Params(1:nApParams(1))';
        peak_ps = reshape(Params((nApParams(1)+1):end), [], 3);
        
        % Compute model
        Model = expo_function(Freq, ap_ps, isFloor);
        for iPeako = 1:nPeaks
            Model = Model + peak_function(Freq, peak_ps(iPeako,1), peak_ps(iPeako,2), peak_ps(iPeako,3));
        end
        
        % Subtract the model from the spectrum.
        % Sum of square residuals
        if isLogError
            err = sum((Spec - Model).^2);
        else
            err = sum((10.^Spec - 10.^Model).^2);
        end
        switch Constraint
            % case {'none', 'constrained'} % do nothing.
            case 'weak' % Add small weight to deviations from guess m and amp
                weak = 1e2;
                PeakGuess = reshape(StartingParams((nApParams(1)+1):end), [], 3);
                err = err + ...
                    weak * sum((peak_ps(:,1) - PeakGuess(:,1)).^2) + ...
                    weak * sum((peak_ps(:,2) - PeakGuess(:,2)).^2);
            case 'strong' % Add large weight to deviations from guess m and amp
                strong = 1e7;
                PeakGuess = reshape(StartingParams((nApParams(1)+1):end), [], 3);
                err = err + ...
                    strong * sum((peak_ps(:,1) - PeakGuess(:,1)).^2) + ...
                    strong * sum((peak_ps(:,2) - PeakGuess(:,2)).^2);
        end
        
    end
    
end


function guess = drop_peak_overlap(guess, proxThresh, freq_range)
%       Checks whether to drop peaks based on amount of overlap.
%
%       Parameters
%       ----------
%       guess : mx3 array, where m = No. of peaks.
%           Guess parameters for peak fits.
%       proxThresh: double
%           Proximity threshold (in st. dev. or gamma) between two peaks.
%
%       Returns
%       -------
%       guess : qx3 where q <= m No. of peaks.
%           Guess parameters for peak fits.
%
%       Note
%       -----
%       For any gaussians with an overlap that crosses the threshold,
%       the lowest height guess guassian is dropped.
    
    if proxThresh <= 0
        return;
    end

    % Add fake delta-function-like peaks at frequency range edges to
    % exclude also peaks that overlap there.
    guess = [guess; ...
        freq_range(1), inf, 0; ...
        freq_range(end), inf, 0];

    % Sort the peak guesses, so can check overlap of adjacent peaks
    guess = sortrows(guess);
    % Double-check no peaks outside accepted range.
    if guess(1,1) < freq_range(1) || guess(end,1) > freq_range(end)
        error('Unexpected peak frequency outside range.');
    end
    % Also sort in descending order of peak height
    [tmp, iH] = sort(guess(:,2), 'desc');

    % By going through peaks in order of greatest amplitude, any that
    % overlap (and not already dropped) is necessarily smaller and should
    % be dropped.
    isDrop = false(size(guess,1), 1);
    for iPeak = iH
        if isDrop(iH)
            continue;
        end
        isDrop = isDrop | ((guess(:, 1) - guess(iH, 1)) < max(guess(iH, 3), guess(:, 3)) * proxThresh);
        isDrop(iH) = false;
    end
    % Remove fake peaks we added for range edges.
    isDrop([1,end]) = true;
    % Remove peaks.
    guess(isDrop,:) = [];
end





%% ===================================================================================
%  ===== FOOOF STATS =================================================================
%  ===================================================================================
function [ePeaks, eAper, eStats] = FOOOF_analysis(FOOOF_data, ChanNames, TF, sort_type, sort_param, sort_bands, isFloor, isMatlab)
    if nargin < 8 || isempty(isFloor)
        isFloor = false;
    end
    
    nChan = numel(ChanNames);

    % ===== EXTRACT APERIODIC =====
    % Organize/extract aperiodic components from FOOOF models
    % Made a bit of a mess changing parameter ordering.
    if isMatlab
        iExp = 1;
        iOff = 2;
    else
        iOff = 1;
        iExp = 2;
    end
    if isFloor
        iFloor = 3;
        iCeil = 0;
    elseif numel(FOOOF_data(1).aperiodic_params) == 4
        iFloor = 4;
        iCeil = 3;
    elseif numel(FOOOF_data(1).aperiodic_params) == 3
        iFloor = 0;
        if isMatlab
            iCeil = 3;
        else
            iCeil = 2;
            iExp = 3;
        end
    else
        iFloor = 0;
        iCeil = 0;
    end
    % Initialize output struct
    eAper = struct('channel', ChanNames, 'exponent', [], 'offset', [], 'ceiling', [], 'floor', []);
    for iChan = 1:nChan
        eAper(iChan).exponent = FOOOF_data(iChan).aperiodic_params(iExp);
        eAper(iChan).offset = FOOOF_data(iChan).aperiodic_params(iOff);
        if iCeil
            eAper(iChan).ceiling = FOOOF_data(iChan).aperiodic_params(iCeil);
        end
        if iFloor
            eAper(iChan).floor = FOOOF_data(iChan).aperiodic_params(iFloor);
        end
    end
    
    % ===== EXTRACT PEAKS =====
    % Organize/extract peak components from FOOOF models
    % Initialize output struct
    ePeaks = struct('channel', [], 'center_frequency', [],...
        'height_factor', [], 'power', [], 'std_dev', [], 'band', []);
    switch sort_type
        case 'param'
            % Collect data from all peaks
            i = 0;
            for iChan = 1:nChan
                if ~isempty(FOOOF_data(iChan).peak_params)
                    Backg = 10.^expo_function(FOOOF_data(iChan).peak_params(:,1), ...
                        [eAper(iChan).exponent, eAper(iChan).offset, eAper(iChan).ceiling, eAper(iChan).floor], isFloor);
                    for p = 1:size(FOOOF_data(iChan).peak_params,1)
                        i = i +1;
                        ePeaks(i).channel = ChanNames(iChan);
                        ePeaks(i).center_frequency = FOOOF_data(iChan).peak_params(p,1);
                        ePeaks(i).height_factor = FOOOF_data(iChan).peak_params(p,2);
                        ePeaks(i).power = (10.^ePeaks(i).height_factor - 1) * Backg(p);
                        ePeaks(i).std_dev = FOOOF_data(iChan).peak_params(p,3);
                    end
                end
            end
            % Apply specified sort
            switch sort_param
                case 'frequency'
                    [tmp,iSort] = sort([ePeaks.center_frequency]); 
                    ePeaks = ePeaks(iSort);
                case 'amplitude'
                    [tmp,iSort] = sort([ePeaks.power]); 
                    ePeaks = ePeaks(iSort(end:-1:1));
                case 'std'
                    [tmp,iSort] = sort([ePeaks.std_dev]); 
                    ePeaks = ePeaks(iSort);
            end 
        case 'band'
            % Generate bands from input
            bands = process_tf_bands('Eval', sort_bands);
            % Collect data from all peaks
            i = 0;
            for iChan = 1:nChan
                if ~isempty(FOOOF_data(iChan).peak_params)
                    Backg = 10.^expo_function(FOOOF_data(iChan).peak_params(:,1), ...
                        [eAper(iChan).exponent, eAper(iChan).offset, eAper(iChan).ceiling, eAper(iChan).floor], isFloor);
                    for p = 1:size(FOOOF_data(iChan).peak_params,1)
                        i = i +1;
                        ePeaks(i).channel = ChanNames(iChan);
                        ePeaks(i).center_frequency = FOOOF_data(iChan).peak_params(p,1);
                        ePeaks(i).height_factor = FOOOF_data(iChan).peak_params(p,2);
                        ePeaks(i).power = (10.^ePeaks(i).height_factor - 1) * Backg(p);
                        ePeaks(i).std_dev = FOOOF_data(iChan).peak_params(p,3);
                        % Find name of frequency band from user definitions
                        bandRanges = cell2mat(bands(:,2));
                        iBand = find(ePeaks(i).center_frequency >= bandRanges(:,1) & ePeaks(i).center_frequency <= bandRanges(:,2));
                        if ~isempty(iBand)
                            ePeaks(i).band = bands{iBand,1};
                        else
                            ePeaks(i).band = 'None';
                        end
                    end
                end
            end
    end

    % ===== EXTRACT STAT =====
    % Organize/extract stats from FOOOF models
    % Initialize output struct
    eStats = struct('channel', ChanNames, 'MSE', {FOOOF_data(iChan).error}, ...
        'r_squared', {FOOOF_data(iChan).r_squared}, 'frequency_wise_error', [], 'frequency_wise_error_lin', []);
    for iChan = 1:nChan
        spec = TF(iChan,:,:);
        fspec = FOOOF_data(iChan).fooofed_spectrum(:)';
        eStats(iChan).frequency_wise_error_lin = abs(spec(:)' - fspec);
        eStats(iChan).frequency_wise_error = abs(log10(spec(:)') - log10(fspec));
    end
end

