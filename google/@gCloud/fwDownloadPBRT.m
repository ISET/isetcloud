function [isetObj,meshImage,label] = fwDownloadPBRT(obj,varargin )
% Download data from gcloud bucket, returning *.dat files as ISET objects
% 
% Syntax:
%  gcp.downloadPBRT();
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
% ZL, Vistalab 2017
%
% See also: piRender

%%
p = inputParser;
varargin = ieParamFormat(varargin);
p.addParameter('scitran',[],@(x)(isa(x,'scitran')));
p.parse(varargin{:});
st = p.Results.scitran;
if isempty(st), st = scitran('stanfordlabs');end
%%
isetObj = cell(1,length(obj.targets));

% We return a file for each of the gcloud targets
for t=1:length(obj.targets)
    
    [~,sceneName]= fileparts(obj.targets(t).local);
    % The targets slot contains the fullpath to the output on the
    % cloud
    sessionName = strsplit(sceneName,'_');
    sessionName = sessionName{1};
    
    % Download files in the acquisition
    %{
    files = st.search('file',...
   'project label exact','Renderings',...
   'session label exact',sessionName,...
   'acquisition label exact',sceneName);
    dataId = files{1}.parent.id;
    %}
    scene_acq =sprintf('wandell/Renderings/%s/%s',sessionName,sceneName);
    acquisition = st.fw.lookup(scene_acq);
    dataId      = acquisition.id;
    
    
    destDir = fullfile(piRootPath,'local',[sessionName,'_',date],'renderings');
    if ~exist(destDir, 'dir'), mkdir(destDir);end
    % Download irradiance image
    destName_irradiance = fullfile(destDir,[sceneName,'.dat']);
    st.fileDownload([sceneName,'.dat'],...
        'container type', 'acquisition' , ...
        'container id',  dataId ,...
        'destination',destName_irradiance);
    fprintf('%s downloaded \n',[sceneName,'.dat']);
    if(obj.renderDepth)
    destName_depth = fullfile(destDir,[sceneName,'_depth.dat']);
    st.fileDownload([sceneName,'_depth.dat'],...
        'container type', 'acquisition' , ...
        'container id',  dataId ,...
        'destination',destName_depth);
    fprintf('%s downloaded \n',[sceneName,'_depth.dat']);
    depthMap = piReadDAT(destName_depth, 'maxPlanes', 31);
    depthMap = depthMap(:,:,1);
    end
    if(obj.renderMesh)
        destName_mesh = fullfile(destDir,[sceneName,'_mesh.dat']);
        st.fileDownload([sceneName,'_mesh.dat'],...
            'container type', 'acquisition' , ...
            'container id',  dataId ,...
            'destination',destName_mesh);
       fprintf('%s downloaded \n',[sceneName,'_mesh.dat']); 
        meshData = piReadDAT(destName_mesh, 'maxPlanes', 31);
        meshImage{t} = meshData(:,:,1);
        % get label file 
        destName_label = fullfile(destDir,[sceneName,'_mesh.txt']);
        label{t} = destName_label;
        st.fileDownload([sceneName,'_mesh_mesh.txt'],...
            'container type', 'acquisition' , ...
            'container id',  dataId ,...
            'destination',destName_label);
        fprintf('%s downloaded \n',[sceneName,'_mesh.txt']); 
    end
    
    % This code should be a separate function, and be shared with
    % piRender.
    if exist(destName_irradiance,'file')
        
    energy = piReadDAT(destName_irradiance, 'maxPlanes', 31);
    % default output is in units of energy
    wave = 400:10:700;
    photons = Energy2Quanta(wave, energy);
    
    ieObjName = sprintf('%s-%s',sceneName,datestr(now,'mmm-dd,HH:MM'));
    if strcmp(obj.targets(t).camera.subtype,'perspective')
        opticsType = 'pinhole';
    else
        opticsType = 'lens';
    end
    
    % If radiance, return a scene or optical image
    switch opticsType
        case 'lens'
            % If we used a lens, the ieObject is an optical image (irradiance).
            
            % We should set fov or filmDiag here.  We should also set other ray
            % trace optics parameters here. We are using defaults for now, but we
            % will find those numbers in the future from inside the radiance.dat
            % file and put them in here.
            ieObject = piOICreate(photons,varargin{:});  % Settable parameters passed
            ieObject = oiSet(ieObject,'name',ieObjName);
            % I think this should work (BW)
            if exist('depthMap','var')
            if(~isempty(depthMap))
                ieObject = oiSet(ieObject,'depth map',depthMap);
            end
            end
            
            % This always worked in ISET, but not in ISETBIO.  So I stuck in a
            % hack to ISETBIO to make it work there temporarily and created an
            % issue. (BW).
            ieObject = oiSet(ieObject,'optics model','ray trace');
            
        case 'pinhole'
            % In this case, we the radiance describes the scene, not an oi
%             ieObject = piSceneCreate(photons,'meanLuminance',100);
            ieObject = piSceneCreate(photons,'meanLuminance',100);
            ieObject = sceneSet(ieObject,'name',ieObjName);
            if exist('depthMap','var')
            if(~isempty(depthMap))
                ieObject = sceneSet(ieObject,'depth map',depthMap);
            end
            end
            
            % There may be other parameters here in this future
            if strcmp(obj.targets(t).camera.subtype,'perspective')
                ieObject = sceneSet(ieObject,'fov',obj.targets(t).camera.fov.value);
            end
    end
    else
        ieObject = [];
    end
    isetObj{t} = ieObject;
    
end

% Clear empty cells in isetObj that were created from depth map targets
if(obj.renderDepth)
    isetObj = isetObj(~cellfun('isempty',isetObj)) ;
end

if (obj.renderMesh)
    meshImage = meshImage(~cellfun('isempty',meshImage));
end

end