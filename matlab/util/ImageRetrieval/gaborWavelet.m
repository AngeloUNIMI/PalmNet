% gaborWavelet - Function for computing gabor features of a gray-scale image
%
% This function calculates gabor features. Mean-squared energy & meanAmplitude 
% for each scale % and orientation is returned.
%
% There are potentially many arguments, here is the full usage:
%
%   [gaborSquareEnergy, gaborMeanAmplitude] = ...
%                gaborWavelet(im, nscale, norient )
%NOTE: nscale & norient are optional arguments

%
% However, apart from the image, all parameters have defaults and the
% usage can be as simple as:
%
%    [gaborSquareEnergy, gaborMeanAmplitude ]= gaborWavelet(im);
% 
% Arguments:
%              Default values      Description
%
%    nscale           5    - Number of wavelet scales, try values 3-6
%    norient          6    - Number of filter orientations.
%
% Return values:
%    msEnergy              - Mean square energy
%    orientation           - Mean amplitude

%
% The convolutions are done via the FFT.  Many of the parameters relate to the
% specification of the filters in the frequency plane.  The values do not seem
% to be very critical and the defaults are usually fine.  You may want to
% experiment with the values of 'nscales' and 'k', the noise compensation factor.
%
% For maximum speed the input image should have dimensions that correspond to
% powers of 2, but the code will operate on images of arbitrary size.

function[gaborSquareEnergy, gaborMeanAmplitude] = gaborWavelet(varargin)

    % Get arguments and/or default values    
    [im, nscale, norient, minWaveLength, mult, sigmaOnf,  dThetaOnSigma,k, ...
     polarity] = checkargs(varargin(:));  

    v = version; Octave = v(1) < '5';  % Crude Octave test    
    epsilon         = .0001;         % Used to prevent division by zero.

    % Calculate the standard deviation of the angular Gaussian function
    % used to construct filters in the frequency plane.     
    thetaSigma = pi/norient/dThetaOnSigma;  
    
    [rows,cols] = size(im);
    imagefft = fft2(im);                % Fourier transform of image
    zero = zeros(rows,cols);
    
    totalEnergy = zero;                 % Matrix for accumulating weighted phase 
                                        % congruency values (energy).
    totalSumAn  = zero;                 % Matrix for accumulating filter response
                                        % amplitude values.
    orientation = zero;                 % Matrix storing orientation with greatest
                                        % energy for each pixel.
    estMeanE2n = [];
    EO = cell(nscale, norient);         % Cell array of convolution results
    ifftFilterArray = cell(1, nscale);  % Cell array of inverse FFTs of filters

    
    % Pre-compute some stuff to speed up filter construction

    % Set up X and Y matrices with ranges normalised to +/- 0.5
    % The following code adjusts things appropriately for odd and even values
    % of rows and columns.
    if mod(cols,2)
	xrange = [-(cols-1)/2:(cols-1)/2]/(cols-1);
    else
	xrange = [-cols/2:(cols/2-1)]/cols;	
    end
    
    if mod(rows,2)
	yrange = [-(rows-1)/2:(rows-1)/2]/(rows-1);
    else
	yrange = [-rows/2:(rows/2-1)]/rows;	
    end
    
    [x,y] = meshgrid(xrange, yrange);
                      
    radius = sqrt(x.^2 + y.^2);       % Matrix values contain *normalised* radius from centre.
    theta = atan2(-y,x);              % Matrix values contain polar angle.
                                      % (note -ve y is used to give +ve
                                      % anti-clockwise angles)

    radius = ifftshift(radius);       % Quadrant shift radius and theta so that filters
    theta  = ifftshift(theta);        % are constructed with 0 frequency at the corners.
    radius(1,1) = 1;                  % Get rid of the 0 radius value at the 0
                                      % frequency point (now at top-left corner)
                                      % so that taking the log of the radius will 
                                      % not cause trouble.				       

    sintheta = sin(theta);
    costheta = cos(theta);
    clear x; clear y; clear theta;    % save a little memory

    % Filters are constructed in terms of two components.
    % 1) The radial component, which controls the frequency band that the filter
    %    responds to
    % 2) The angular component, which controls the orientation that the filter
    %    responds to.
    % The two components are multiplied together to construct the overall filter.
    
    % Construct the radial filter components...
    
    % First construct a low-pass filter that is as large as possible, yet falls
    % away to zero at the boundaries.  All log Gabor filters are multiplied by
    % this to ensure no extra frequencies at the 'corners' of the FFT are
    % incorporated as this seems to upset the normalisation process when
    % calculating phase congrunecy.
    lp = lowpassfilter([rows,cols], .4, 10);   % Radius .4, 'sharpness' 10

    logGabor = cell(1, nscale);
    
    for s = 1:nscale
        wavelength = minWaveLength*mult^(s-1);
        fo = 1.0/wavelength;                  % Centre frequency of filter.
        logGabor{s} = exp((-(log(radius/fo)).^2) / (2 * log(sigmaOnf)^2));  
        logGabor{s} = logGabor{s}.*lp;        % Apply low-pass filter
        logGabor{s}(1, 1) = 0;                 % Set the value at the 0 frequency point of the filter
                                              % back to zero (undo the radius fudge).
    end

    % Then construct the angular filter components...
    spread = cell(1, norient);
    
    for o = 1:norient
        angl = (o-1)*pi/norient;           % Filter angle.
        
        % For each point in the filter matrix calculate the angular distance from
        % the specified filter orientation.  To overcome the angular wrap-around
        % problem sine difference and cosine difference values are first computed
        % and then the atan2 function is used to determine angular distance.
        
        ds = sintheta * cos(angl) - costheta * sin(angl);    % Difference in sine.
        dc = costheta * cos(angl) + sintheta * sin(angl);    % Difference in cosine.
        dtheta = abs(atan2(ds,dc));                          % Absolute angular distance.
        spread{o} = exp((-dtheta.^2) / (2 * thetaSigma^2));  % Calculate the
                                                             % angular filter component.
    end

count = 1;
gaborSquareEnergy = [];
gaborMeanAmplitude = [];
    % The main loop...
    for o = 1:norient,                   % For each orientation.
        fprintf('Processing orientation %d \r', o); 
        if Octave fflush(1); end
	
        sumAn_ThisOrient  = zero;      
        Energy_ThisOrient = zero;      

        for s = 1:nscale,                  % For each scale.

            filter = logGabor{s} .* spread{o};  % Multiply radial and angular
                                                % components to get filter.

            ifftFilt = real(ifft2(filter))*sqrt(rows*cols);  % Note rescaling to match power
            ifftFilterArray{s} = ifftFilt;                   % record ifft2 of filter

            % Convolve image with even and odd filters returning the result in EO
            EO{s, o} = ifft2(imagefft .* filter);
            An  = abs(EO{s,o});                        % Amplitude of even & odd filter response.
            sumAn_ThisOrient = sumAn_ThisOrient + An; % Sum of amplitude responses.
            
%             % Display of individual components
%             if o == 6
%             figure, imagesc( An ), colormap(gray), title( sprintf( 'orient : %d, scale : %d', o,s) );
%             imwrite( An, sprintf( 'orient/%d/%d.png', o,s ) );

		gaborSquareEnergy(count) = sum(sum( An.^2 ) );
		gaborMeanAmplitude(count) = mean2( An );
 		count = count + 1;

%             end
            
            if s==1
                EM_n = sum(sum(filter.^2)); % Record mean squared filter value at smallest
            end                             % scale. This is used for noise estimation.

        end                                 % ... and process the next scale

        % calculate the phase symmetry measure

        if polarity == 0     % look for 'white' and 'black' spots
            for s = 1:nscale,                  
                Energy_ThisOrient = Energy_ThisOrient ...
                    + abs(real(EO{s,o})) - abs(imag(EO{s,o}));
            end
            
        elseif polarity == 1  % Just look for 'white' spots
            for s = 1:nscale,                  
                Energy_ThisOrient = Energy_ThisOrient ...
                    + real(EO{s,o}) - abs(imag(EO{s,o}));
            end
            
        elseif polarity == -1  % Just look for 'black' spots
            for s = 1:nscale,                  
                Energy_ThisOrient = Energy_ThisOrient ...
                    - real(EO{s,o}) - abs(imag(EO{s,o}));
            end      
      
        end
        
        % Compensate for noise
        % We estimate the noise power from the energy squared response at the
        % smallest scale.  If the noise is Gaussian the energy squared will
        % have a Chi-squared 2DOF pdf.  We calculate the median energy squared
        % response as this is a robust statistic.  From this we estimate the
        % mean.  The estimate of noise power is obtained by dividing the mean
        % squared energy value by the mean squared filter value
        
        medianE2n  = median(reshape(abs(EO{1,o}).^2,1,rows*cols));
        meanE2n    = -medianE2n/log(0.5);
        estMeanE2n = [estMeanE2n meanE2n];
        
        noisePower = meanE2n/EM_n; % Estimate of noise power.
        
        % Now estimate the total energy^2 due to noise
        % Estimate for sum(An^2) + sum(Ai.*Aj.*(cphi.*cphj + sphi.*sphj))
        
        EstSumAn2 = zero;
        for s = 1:nscale
            EstSumAn2 = EstSumAn2+ifftFilterArray{s}.^2;
        end
        
        EstSumAiAj = zero;
        for si = 1:(nscale - 1)
            for sj = (si + 1):nscale
                EstSumAiAj = EstSumAiAj + ifftFilterArray{si} .* ifftFilterArray{sj};
            end
        end
        
        EstNoiseEnergy2 = 2*noisePower*sum(sum(EstSumAn2)) + 4*noisePower*sum(sum(EstSumAiAj));
        
        tau = sqrt(EstNoiseEnergy2/2);                % Rayleigh parameter
        EstNoiseEnergy = tau*sqrt(pi/2);              % Expected value of noise energy
        EstNoiseEnergySigma = sqrt( (2-pi/2)*tau^2 );
        
        T =  EstNoiseEnergy + k*EstNoiseEnergySigma;  % Noise threshold
        
        % The estimated noise effect calculated above is only valid for the PC_1
        % measure.  The PC_2 measure does not lend itself readily to the same
        % analysis.  However empirically it seems that the noise effect is
        % overestimated roughly by a factor of 1.7 for the filter parameters
        % used here.
        T = T/1.7;    

        % Apply noise threshold 
        Energy_ThisOrient = max(Energy_ThisOrient - T, zero); 
                          
        % Update accumulator matrix for sumAn and totalEnergy
        totalSumAn  = totalSumAn + sumAn_ThisOrient;
        totalEnergy = totalEnergy + Energy_ThisOrient;
        
        % Update orientation matrix by finding image points where the energy in
        % this orientation is greater than in any previous orientation (the
        % change matrix) and then replacing these elements in the orientation
        % matrix with the current orientation number.
        
        if(o == 1),
            maxEnergy = Energy_ThisOrient;
        else
            change = Energy_ThisOrient > maxEnergy;
            orientation = (o - 1).*change + orientation.*(~change);
            maxEnergy = max(maxEnergy, Energy_ThisOrient);
        end
        
    end  % For each orientation
    fprintf('                                   \r');
    

    display( 'Code for <Variation in Phase Symetry> Starts' );
    %
    % Desc: 
    % We are trying out a variant of phase symetry. Our measure of symetry
    % is average across all orientations and scales, instead of normal
    % addition. This was done so that, maximas in particular direction only
    % could be eliminated. Also, the obervation was that a cell-center
    % point would be symetric in all direction and a high value in all
    % direction. 
    averageDirectionalEnergy = zero;
%     for s=1:nscale
%         for o=1:norient
%             averageDirectionalEnergy = averageDirectionalEnergy + abs(EO{s,o});
%         end
%     end
%     averageDirectionalEnergy = averageDirectionalEnergy / (nscale * norient );
%     
    
    
    %
    % Computing median image
    %    median is computed over orientations. which means for a
    %    particular scale, orientation is varied to take the median
    
    
    for sc = 1:nscale
    clear XA;
    clear XE;
    display( sprintf( 'Taking Median for scale %d/%d', sc, nscale ) );
    scale_current = sc;
    % for a fixed scale, iterate thru each orientation
    for ori=1:norient
        XA(:, :, ori) = abs( EO{scale_current, ori} );
        XE(:, :, ori) = abs( real(EO{scale_current, ori}) ) - abs( imag(EO{scale_current, ori}) );
    end
   
    
     % % % Basic Approach 
     %mA(:,:,scale_current) = median( XA, 3 );
     %mE(:,:,scale_current) = median( XE, 3 );
     
     % % % Approach for optimization. 3d array reshaped to 2d
     appr_r_XA = reshape( XA, [ size(XA,1)*size(XA,2) norient ] );
     appr_r_median_XA = median( appr_r_XA, 2 );
     mA = reshape( appr_r_median_XA, [size(XA,1) size(XA,2) ] );
     
     appr_r_XE = reshape( XE, [ size(XE,1)*size(XE,2) norient ] );
     appr_r_median_XE = median( appr_r_XE, 2 );
     mE = reshape( appr_r_median_XE, [size(XE,1) size(XE,2) ] );
     

%     figure,imagesc( tmp )
%     colormap(gray), title( sprintf( 'scale : %d', sc ) );
    end
    A = sum( mA, 3 );
    E = sum( mE, 3 );
    
    averageDirectionalEnergy = E ./ (A + epsilon);

%     for ori=1:norient
%     clear XP;
%     % for a fixed scale, iterate thru each orientation
%     for sc = 1:nscale
%         scale_current = sc;
%         XP(:,:,sc) = abs( EO{scale_current,ori} );
%     end
%    
%      tmp= median( XP, 3 );
%      %rel(:,:,scale_current)
%     
%     figure,imagesc( tmp )
%     colormap(gray), title( sprintf( 'orientation : %d', ori ) );
%     end


display( 'Code End for <Variation in Phase Symetry>' );

%
% End of code for <Variation in Phase Symetry>
%
    
    
%    disp('Mean Energy squared values recorded with smallest scale filter at each orientation');
%    disp(estMeanE2n);
    
    % Normalize totalEnergy by the totalSumAn to obtain phase symmetry
    phaseSym = totalEnergy ./ (totalSumAn + epsilon);
    
    % Convert orientation matrix values to degrees
    orientation = orientation * (180 / norient);
    
    
%------------------------------------------------------------------
% CHECKARGS
%
% Function to process the arguments that have been supplied, assign
% default values as needed and perform basic checks.
    
function [im, nscale, norient, minWaveLength, mult, sigmaOnf, ...
          dThetaOnSigma,k, polarity] = checkargs(arg); 

    nargs = length(arg);
    
    if nargs < 1
        error('No image supplied as an argument');
    end    
    
    % Set up default values for all arguments and then overwrite them
    % with with any new values that may be supplied
    im              = [];
    nscale          = 5;     % Number of wavelet scales.    
    norient         = 6;     % Number of filter orientations.
    minWaveLength   = 3;     % Wavelength of smallest scale filter.    
    mult            = 2.1;   % Scaling factor between successive filters.    
    sigmaOnf        = 0.55;  % Ratio of the standard deviation of the
                             % Gaussian describing the log Gabor filter's
                             % transfer function in the frequency domain
                             % to the filter center frequency.    
    dThetaOnSigma   = 1.2;   % Ratio of angular interval between filter orientations    
                             % and the standard deviation of the angular Gaussian
                             % function used to construct filters in the
                             % freq. plane.
    k               = 2.0;   % No of standard deviations of the noise
                             % energy beyond the mean at which we set the
                             % noise threshold point. 

    polarity        = 0;     % Look for both black and white spots of symmetrry

    
    % Allowed argument reading states
    allnumeric   = 1;       % Numeric argument values in predefined order
    keywordvalue = 2;       % Arguments in the form of string keyword
                            % followed by numeric value
    readstate = allnumeric; % Start in the allnumeric state
    
    if readstate == allnumeric
        for n = 1:nargs
            if isa(arg{n}, 'char')
                readstate = keywordvalue;
                break;
            else
                if     n == 1, im            = arg{n}; 
                elseif n == 2, nscale        = arg{n};              
                elseif n == 3, norient       = arg{n};
                elseif n == 4, minWaveLength = arg{n};
                elseif n == 5, mult          = arg{n};
                elseif n == 6, sigmaOnf      = arg{n};
                elseif n == 7, dThetaOnSigma = arg{n};
                elseif n == 8, k             = arg{n};              
                elseif n == 9, polarity      = arg{n};                              
                end
            end
        end
    end

    % Code to handle parameter name - value pairs
    if readstate == keywordvalue
        while n < nargs
            
            if ~isa(arg{n},'char') | ~isa(arg{n+1}, 'double')
                error('There should be a parameter name - value pair');
            end
            
            if     strncmpi(arg{n},'im'      ,2), im =        arg{n+1};
            elseif strncmpi(arg{n},'nscale'  ,2), nscale =    arg{n+1};
            elseif strncmpi(arg{n},'norient' ,2), norient =   arg{n+1};
            elseif strncmpi(arg{n},'minWaveLength',2), minWavelength = arg{n+1};
            elseif strncmpi(arg{n},'mult'    ,2), mult =      arg{n+1};
            elseif strncmpi(arg{n},'sigmaOnf',2), sigmaOnf =  arg{n+1};
            elseif strncmpi(arg{n},'dthetaOnSigma',2), dThetaOnSigma =  arg{n+1};
            elseif strncmpi(arg{n},'k'       ,1), k =         arg{n+1};
            elseif strncmpi(arg{n},'polarity',2), polarity =  arg{n+1};
            else   error('Unrecognised parameter name');
            end

            n = n+2;
            if n == nargs
                error('Unmatched parameter name - value pair');
            end
            
        end
    end
    
    if isempty(im)
        error('No image argument supplied');
    end

    if ~isa(im, 'double')
        im = double(im);
    end
    
    if nscale < 1
        error('nscale must be an integer >= 1');
    end
    
    if norient < 1 
        error('norient must be an integer >= 1');
    end    

    if minWaveLength < 2
        error('It makes little sense to have a wavelength < 2');
    end          
        
    if polarity ~= -1 & polarity ~= 0 & polarity ~= 1
        error('Allowed polarity values are -1, 0 and 1')
    end