function fwBatchProcessPBRT(obj,varargin )
% Download data from flywheel and annotate them.
% Save optical image at desired folder.
%
% Syntax:
%  gcp.fwBatchProcessPBRT();
%
% Input (required)
%   thisR:  A render recipe.
%
% Inputs (optional)
%
% Return
%  isetObj - a cell array of ISET scene or oi (depending on the recipe
%            optics)
%
% ZL, Vistalab 2019
%
% See also: piRender

%%
p = inputParser;
varargin = ieParamFormat(varargin);
p.addParameter('scitran',[],@(x)(isa(x,'scitran')));
p.addParameter('destinationdir','',@ischar);
p.parse(varargin{:});
st = p.Results.scitran;
destDir = p.Results.destinationdir;
if isempty(st), st = scitran('stanfordlabs');end

%% We return a file for each of the gcloud targets
for tt = 1:length(obj.targets)
    
    [~,sceneName]= fileparts(obj.targets(tt).local);
    % The targets slot contains the fullpath to the output on the
    % cloud
    sessionName = strsplit(sceneName,'_');
    sessionName = sessionName{1};
    
    scene_acq =sprintf('wandell/Renderings/%s/%s',sessionName,sceneName);
    try
    acquisition = st.fw.lookup(scene_acq);
    catch
        fprintf('%s acquisition not found',scene_acq);
        continue
    end
    dataId      = acquisition.id;
    % on holidayfun instance --zhenyi
    %     destDir = fullfile(piRootPath,'local',[sessionName,'_',date],'renderings');
    if ~exist(destDir, 'dir'), mkdir(destDir);end
    % Download irradiance image
    destName_irradiance = fullfile(destDir,[sceneName,'.dat']);
    if ~exist(destName_irradiance,'file')
        try
            st.fileDownload([sceneName,'.dat'],...
                'container type', 'acquisition' , ...
                'container id',  dataId ,...
                'destination',destName_irradiance);
            fprintf('%s downloaded. \n',[sceneName,'.dat']);
        catch
            fprintf('Target %d Not found in Flywheel',tt);
            continue
        end
        
    else
        fprintf('%s already exist. \n',[sceneName,'.dat']);
    end
    
    % Download scene recipe
    destName_recipe = fullfile(destDir,[sceneName,'.json']);
%     acqRecipe = st.fw.lookup(sprintf('wandell/Graphics assets/scenes_pbrt/%s',sceneName));
    acqRecipe = st.fw.lookup(sprintf('wandell/Renderings/scene_pbrt/%s',sceneName));

    acqdataId = acqRecipe.id;
    % download the file
    if ~exist(destName_recipe,'file')
        try
            st.fileDownload([sceneName,'.json'],...
                'container type', 'acquisition' , ...
                'container id',  acqdataId ,...
                'destination',destName_recipe);
            fprintf('%s downloaded \n',[sceneName,'.json']);
        catch
            fprintf('%s not found \n',[sceneName,'.json']);
            continue
        end
    else
        fprintf('%s already exist \n',[sceneName,'.json']);
    end
    thisR_tmp = jsonread(destName_recipe);
    fds = fieldnames(thisR_tmp);
    thisR = recipe;
    for dd = 1:length(fds)
        thisR.(fds{dd})= thisR_tmp.(fds{dd});
    end
    
    if(obj.renderDepth)
        destName_depth = fullfile(destDir,[sceneName,'_depth.dat']);
        if ~exist(destName_depth,'file')
            try
                st.fileDownload([sceneName,'_depth.dat'],...
                    'container type', 'acquisition' , ...
                    'container id',  dataId ,...
                    'destination',destName_depth);
                fprintf('%s downloaded \n',[sceneName,'_depth.dat']);
            catch
                fprintf('%s not found \n',[sceneName,'_depth.dat']);
                continue
            end
        else
            fprintf('%s already exist \n',[sceneName,'_depth.dat']);
        end
        depthMap = piReadDAT(destName_depth, 'maxPlanes', 31);
        depthMap = depthMap(:,:,1);
    end
    if(obj.renderMesh)
        destName_mesh = fullfile(destDir,[sceneName,'_mesh.dat']);
        if ~exist(destName_mesh,'file')
            try
                st.fileDownload([sceneName,'_mesh.dat'],...
                    'container type', 'acquisition' , ...
                    'container id',  dataId ,...
                    'destination',destName_mesh);
                fprintf('%s downloaded \n',[sceneName,'_mesh.dat']);
            catch
                fprintf('%s not found \n',[sceneName,'_mesh.dat']);
                continue
            end
        else
            fprintf('%s already exist \n',[sceneName,'_mesh.dat']);
        end
        meshData = piReadDAT(destName_mesh, 'maxPlanes', 31);
        meshImage = meshData(:,:,1);
        % get label file
        destName_label = fullfile(destDir,[sceneName,'_mesh.txt']);
        label = destName_label;
        if ~exist(destName_label,'file')
            try
                st.fileDownload([sceneName,'_mesh_mesh.txt'],...
                    'container type', 'acquisition' , ...
                    'container id',  dataId ,...
                    'destination',destName_label);
                fprintf('%s downloaded \n',[sceneName,'_mesh.txt']);
            catch
                fprintf('%s not found \n',[sceneName,'_mesh.txt']);
                continue
            end
        else
            fprintf('%s already exist \n',[sceneName,'_mesh.txt']);
        end
    end
    
    % This code should be a separate function, and be shared with
    % piRender.
    isetObj = piDat2ISET(destName_irradiance,...
        'label','radiance','recipe',thisR); 
    %% Annotation
    ieObject = piFireFliesRemove(isetObj);
    pngFigure = oiGet(ieObject,'rgb image');
    sceneFigureDir = fullfile(destDir,'OIpngPreviews');
    if ~exist(sceneFigureDir,'dir'), mkdir(sceneFigureDir);end
    irradiancefile = fullfile(sceneFigureDir,[sceneName,'.png']);
    imwrite(pngFigure,irradiancefile);
    ieObject.metadata.daytime    = thisR.metadata.daytime;
    ieObject.metadata.objects    = thisR.assets;
    ieObject.metadata.camera     = thisR.camera;
    ieObject.metadata.film       = thisR.film;
    if obj.renderDepth==1 && obj.renderMesh==1
        %% mesh_txt
        data=importdata(label);
        meshtxt = regexp(data, '\s+', 'split');
        ieObject = sceneSet(ieObject,'depth map',depthMap);
        meshImage = uint16(meshImage);
        ieObject.metadata.meshImage = meshImage;
        ieObject.metadata.meshtxt   = meshtxt;
    end
    oiDir = fullfile(destDir,'opticalImages');
    if ~exist(oiDir,'dir'),mkdir(oiDir);end
    oiFilepath = fullfile(oiDir,[sceneName,'.mat']);
    save(oiFilepath,'ieObject');
    fprintf('***%d optical Image: %s is saved*** \n',tt,oiFilepath);
    %{
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
    %%
    
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

%     close all;
%     clearvars -global -except gcp st destDir
%     else
%        disp('No object in the scene');
% end
    %}
    clearvars -global -except gcp st destDir
    delete(destName_irradiance);
    if obj.renderDepth==1 && obj.renderMesh==1
    delete(destName_mesh);
    delete(destName_depth);
    end
end


end