function OutImg = Gabor_output(InImg, bestWavelets, NumFilters)

%init
ImgZ = length(InImg);
OutImg = cell(NumFilters*ImgZ,1); 

%init
gaborResponses = cell(ImgZ, 1);

%loop on images
for i = 1 : ImgZ
    %image
    img = InImg{i};
    gaborResponses{i} = computeGaborResponses(img, bestWavelets, NumFilters);
end %parfor i = 1 : ImgZ

%assign to global structure
cnt = 0;
for i = 1 : ImgZ
    for j = 1 : NumFilters  
        cnt = cnt + 1;
        OutImg{cnt} = gaborResponses{i}(:,:,j);
        
%         figure(11)
%         subplot(1,2,1)
%         imshow(OutImg{cnt},[]);
%         title(num2str(j))
%         subplot(1,2,2)
%         imshow(OutImg{cnt}>0,[]);
%         pause
        
    end %for j = 1:NumFilters
    
    %clear
    InImg{i} = [];
    
end %for i = 1 : ImgZ

