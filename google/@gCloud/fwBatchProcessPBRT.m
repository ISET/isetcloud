function ieObject = fwBatchProcessPBRT(obj,varargin )
% Download radiance and annotation data from flywheel
%
% Syntax:
%  ieObject = gcp.fwBatchProcessPBRT();
%   
% Input (required)
%   obj:    gCloud object
%
% Key/val options
%   destinationDir:  Local directory for the object
%   scitran:         scitran object
%
% Return
%  isetObj - a cell array of ISET scene or oi structs.
%
% Description
%   Goes to gCloud to download the rendered PBRT data. Saves optical image
%   and perhaps annotation (metadata) in the destination directory. Some
%   minor processing is done to remove 'fire flies' from the rendered
%   image, and to copy the json recipe information into a Matlab recipe
%   class.
%
% ZL, Vistalab 2019
%
% See also: 
%   piRender

%%

varargin = ieParamFormat(varargin);

p = inputParser;
p.addParameter('scitran',[],@(x)(isa(x,'scitran')));
p.addParameter('destinationdir','',@ischar);
% The json recipe will be here.  The rendering will be in this project
% with a subject slot of 'rendering'
p.addParameter('scenesubject','wandell/Graphics auto renderings/scenes');
p.parse(varargin{:});

st      = p.Results.scitran;
destDir = p.Results.destinationdir;
sceneSubject = p.Results.scenesubject;

if isempty(st), st = scitran('stanfordlabs');end

%% We return a file for each of the gcloud targets
for tt = 1:length(obj.targets)
    
    [~,sceneName]= fileparts(obj.targets(tt).local);
    % The targets slot contains the fullpath to the output on the
    % cloud
    sessionName = strsplit(sceneName,'_');
    sessionName = sessionName{1};
    
    % This is where the rendering
    renderSubject = st.lookup('wandell/Graphics auto renderings/renderings');
    session = renderSubject.sessions.findOne(sprintf('label=%s',sessionName));
    try
        acq = session.acquisitions.findOne(sprintf('label=%s',sceneName));
    catch
        fprintf('Acquisition: %s not found.\nReturning empty iset object.\n',sceneName);
        ieObject = [];
        continue
    end
    
    % on holidayfun instance --zhenyi
    %     destDir = fullfile(piRootPath,'local',[sessionName,'_',date],'renderings');
    if ~exist(destDir, 'dir'), mkdir(destDir);end
    
    % Download irradiance image
    destName_irradiance = fullfile(destDir,[sceneName,'.dat']);
    if ~exist(destName_irradiance,'file')
        try
            % Try to download it
            thisFile  = acq.getFile([sceneName,'.dat']); 
            thisFile.download(destName_irradiance);
            fprintf('%s downloaded. \n',[sceneName,'.dat']);
        catch
            % Can not find it
            fprintf('Target %d Not found in Flywheel. \n',tt);
            continue
        end
    else
        % It exists, so do not over-write
        fprintf('Target %s already exists. \n',[sceneName,'.dat']);
    end
    
    % Download scene recipe from Graphics assets project.
    destName_recipe = fullfile(destDir,[sceneName,'.json']);
    str = fullfile(sceneSubject,sessionName,sceneName);
    acqRecipe = st.lookup(str);

%     thisSession  =  sceneSubject.addSession('label', sessionName{1});
%     GAssets = st.lookup('wandell/Graphics auto/scenes');
%     sessionRecipe = thisSession.findOne('label=scenes_pbrt');
%     acqRecipe= sessionRecipe.acquisitions.findOne(sprintf('label=%s',sceneName));
    
    % download the recipe json file
    if ~exist(destName_recipe,'file')
        try
            thisFile  = acqRecipe.getFile([sceneName,'.json']); 
            thisFile.download(destName_recipe);
            fprintf('%s downloaded \n',[sceneName,'.json']);
        catch
            fprintf('%s not found \n',[sceneName,'.json']);
            continue
        end
    else
        fprintf('%s already exist \n',[sceneName,'.json']);
    end
    
    % Read it and parse it into the local recipe class
    thisR = piJson2Recipe(destName_recipe);
    % If it has depth
    if(obj.renderDepth)
        destName_depth = fullfile(destDir,[sceneName,'_depth.dat']);
        if ~exist(destName_depth,'file')
            try
                thisFile  = acq.getFile([sceneName,'_depth.dat']); 
                thisFile.download(destName_depth);                
                fprintf('%s downloaded \n',[sceneName,'_depth.dat']);
            catch
                fprintf('%s not found \n',[sceneName,'_depth.dat']);
                continue
            end
        else
            fprintf('%s already exist \n',[sceneName,'_depth.dat']);
        end
        depthMap = piDat2ISET(destName_depth, 'label', 'depth');
    end
    
    % If it has coordinate
    if (obj.renderPointCloud)
        destName_coord = fullfile(destDir,[sceneName,'_coordinates.dat']);
        if ~exist(destName_coord,'file')
            try
                thisFile  = acq.getFile([sceneName,'_coordinates.dat']);
                thisFile.download(destName_coord);
                fprintf('%s downloaded \n',[sceneName,'_coordinates.dat']);
            catch
                fprintf('%s not found \n',[sceneName,'_coordinates.dat']);
                continue
            end
        else
            fprintf('%s already exist \n',[sceneName,'_coordinates.dat']);
        end
        
        coordMap = piDat2ISET(destName_coord,'label','coordinates');
    end
    
    % If it has a mesh
    if(obj.renderMesh)
        destName_mesh = fullfile(destDir,[sceneName,'_mesh.dat']);
        if ~exist(destName_mesh,'file')
            try
                thisFile  = acq.getFile([sceneName,'_mesh.dat']); 
                thisFile.download(destName_mesh);
                fprintf('%s downloaded \n',[sceneName,'_mesh.dat']);
            catch
                fprintf('%s not found \n',[sceneName,'_mesh.dat']);
                continue
            end
        else
            fprintf('%s already exist \n',[sceneName,'_mesh.dat']);
        end
        meshImage = piDat2ISET(destName_mesh, 'label', 'mesh');
        
        % get label file
        destName_label = fullfile(destDir,[sceneName,'_mesh.txt']);
        label = destName_label;
        if ~exist(destName_label,'file')
            try
                thisFile  = acq.getFile([sceneName,'_mesh_mesh.txt']); 
                thisFile.download(destName_label);               
                fprintf('%s downloaded \n',[sceneName,'_mesh.txt']);
            catch
                fprintf('%s not found \n',[sceneName,'_mesh.txt']);
                continue
            end
        else
            fprintf('%s already exist \n',[sceneName,'_mesh.txt']);
        end
    end
    
    % Read the PBRT dat file into the iset object
    isetObj = piDat2ISET(destName_irradiance,...
        'label','radiance','recipe',thisR);
        
    % Removies fire flies (little white spots) from the image
    ieObject = piFireFliesRemove(isetObj);
    
    %% Save out a png of the rendering
    pngFigure = oiGet(ieObject,'rgb image');
    sceneFigureDir = fullfile(destDir,'OIpngPreviews');
    if ~exist(sceneFigureDir,'dir'), mkdir(sceneFigureDir);end
    irradiancefile = fullfile(sceneFigureDir,[sceneName,'.png']);
    imwrite(pngFigure,irradiancefile);
    
    %% Add some metadata to the ISET object

    ieObject.metadata.daytime    = thisR.metadata.daytime;
    ieObject.metadata.objects    = thisR.assets;
    ieObject.metadata.camera     = thisR.camera;
    ieObject.metadata.film       = thisR.film;
    
    if obj.renderMesh==1
        % mesh_txt
        data=importdata(label);
        meshtxt = regexp(data, '\s+', 'split');
        
        meshImage = uint16(meshImage);
        ieObject.metadata.meshImage  = meshImage;
        ieObject.metadata.meshtxt    = meshtxt;
    end
    if obj.renderDepth
        ieObject = sceneSet(ieObject,'depth map',depthMap); 
    end
    if obj.renderPointCloud
        ieObject.metadata.pointcloud = coordMap;
    end
    
    %% Save the oi
    oiDir = fullfile(destDir,'opticalImages');
    if ~exist(oiDir,'dir'),mkdir(oiDir);end
    oiFilepath = fullfile(oiDir,[sceneName,'.mat']);
    save(oiFilepath,'ieObject');
    fprintf('***%d optical Image: %s is saved*** \n',tt,oiFilepath);
    
    % Clean up
    clearvars -global -except gcp st destDir
    delete(destName_irradiance);
    
    if obj.renderDepth, delete(destName_depth);end
    if obj.renderMesh, delete(destName_mesh);end
    if obj.renderPointCloud, delete(destName_coord);end
end

end

%{

% Deprecated code

oiWindow;
oiSet(isetObj_corrected,'gamma',0.8);
pngFigure = oiGet(isetObj_corrected,'rgb image');
sceneFigureDir = fullfile(destDir,sceneName);
if ~exist(sceneFigureDir,'dir'),mkdir(sceneFigureDir);end

% Get the class labels, depth map, bounding boxes for ground
% truth. This usually takes about 15 secs
isetObj_corrected = piBatchSceneAnnotation(isetObj_corrected,meshImage,label,thisR);
irradiancefile = fullfile(sceneFigureDir,[sceneName,'_ir.png']);
imwrite(pngFigure,irradiancefile);
oiDir = fullfile(destDir,'opticalImages');
if ~exist(oiDir,'dir'),mkdir(oiDir);end
oiFilepath = fullfile(oiDir,[sceneName,'.mat']);
save(oiFilepath,'isetObj_corrected');
fprintf('%d optical Image: %s is saved \n',tt,oiFilepath);


annotationFig = figure;
imshow(pngFigure);
if ~isempty(isetObj_corrected.metadata.bbox2d)
    fds = fieldnames(isetObj_corrected.metadata.bbox2d);
    for kk = 1:length(fds)
        detections = isetObj_corrected.metadata.bbox2d.(fds{kk});
        r = rand; g = rand; b = rand;
        if r< 0.2 && g < 0.2 && b< 0.2
            r = 0.5; g = rand; b = rand;
        end
        for jj=1:length(detections)
            if ~detections{jj}.ignore
                pos = [detections{jj}.bbox2d.xmin detections{jj}.bbox2d.ymin ...
                    detections{jj}.bbox2d.xmax-detections{jj}.bbox2d.xmin ...
                    detections{jj}.bbox2d.ymax-detections{jj}.bbox2d.ymin];
                
                rectangle('Position',pos,'EdgeColor',[r g b],'LineWidth',1);
                %         t=text(detections{jj}.bbox2d.xmin+2.5,detections{jj}.bbox2d.ymin-8,num2str(jj));
                tex=text(detections{jj}.bbox2d.xmin+2.5,detections{jj}.bbox2d.ymin-8,fds{kk});
                tex.Color = [0 0 0];
                tex.BackgroundColor = [r g b];
                tex.FontSize = 5;
            end
        end
        
    end
    drawnow;
    annotationfile = fullfile(sceneFigureDir,[sceneName,'_annotation.png']);
    saveas(annotationFig,annotationfile,'png');
    
    close all;
    clearvars -global -except gcp st destDir
else
    disp('No object in the scene');
end
%}