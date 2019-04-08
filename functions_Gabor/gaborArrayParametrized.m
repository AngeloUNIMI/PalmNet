function gabor = gaborArrayParametrized(sigma, wavelength, orient_chosen)
 
% Bounding box
halfLength = 17;

xmax = halfLength;
xmin = -halfLength; 
ymax = halfLength;
ymin = -halfLength;
[x,y] = meshgrid(xmin:xmax,ymin:ymax);

%init
gabor(numel(orient_chosen)).filter = [];

%loop on angles
%for oriIndex = 1 : divTheta
for oriIndex = 1 : numel(orient_chosen)
    
    %theta = pi / divTheta * (oriIndex - 1);
    theta = orient_chosen(oriIndex);
    
    % Rotation 
    %x_theta=x*cos(theta)+y*sin(theta);
    %y_theta=-x*sin(theta)+y*cos(theta);
   
    %gb = exp(-.5*((x_theta.^2 + y_theta.^2)/sigma^2)).*cos(2*pi/lambda*x_theta);
    %gb=exp(-.5*(x_theta.^2/sigma^2+y_theta.^2/(ratio * sigma)^2)).*cos(2*pi/wavelength*x_theta);
    
    %lldp
    x_theta=x;
    y_theta=y;
    gb = (1 / (2.*pi.*sigma.^2)) .* exp( - (x_theta.^2 + y_theta.^2) / (2.*sigma.^2) ) .* ...
        exp(2 .* pi .* 1i .* (wavelength .* x_theta .* cos(theta) + wavelength .* y_theta .* sin(theta)));
    
%     figure,
%     imshow(gb,[])
%     pause

    %gabor(:, :, oriIndex) = gb;
    gabor(oriIndex).filter = gb;
    %gabor(oriIndex).theta = theta;
    
end %for oriIndex = 1 : divTheta
