%% Change the material properties in a V3 PBRT scene
%
% ZL SCIEN Team, 2018


%% Initialize ISET, Google cloud SDK and Docker

ieInit;
if ~mcDockerExists, mcDockerConfig; end % check whether we can use docker
if ~mcGcloudExists, mcGcloudConfig; end % check whether we can use google cloud sdk;

%% Initialize your cluster

tic
gcp = gCloud('configuration','gcp-pbrtv3-central-32');
toc

% Show where
gcp.targets =[];

% Show where we stand
str = gcp.configList;

%% Read pbrt_material files
FilePath = fullfile(piRootPath,'data','V3','SimpleScene');
fname = fullfile(FilePath,'SimpleScene.pbrt');
if ~exist(fname,'file'), error('File not found'); end

% Warnings may appear about filter and Renderer
thisR = piRead(fname,'version',3);

%% Set render quality

thisR.set('filmresolution',[800 600]);
thisR.set('pixelsamples',64);

%% List material library

% it's helpful to check what current material properties are.
% piMaterialList(thisR);

fprintf('A library of materials\n\n');  % Needs a nicer print method
disp(thisR.materials.lib)

% This value determines the number of bounces.  To have glass we need
% to have at least 2 or more.  We start with only 1 bounce, so it will
% not appear like glass or mirror.
thisR.integrator.maxdepth.value = 8;

%% Write out the pbrt scene file, based on thisR.
[~,n,e] = fileparts(fname); 
oFile = sprintf('%s-1%s',n,e);
thisR.set('outputFile',fullfile(mcRootPath,'local','SimpleSceneExport',oFile));

% material.pbrt is supposed to overwrite itself.
piWrite(thisR);

% Set parameters for multiple scenes, same geometry and materials
gcp.uploadPBRT(thisR);  
addPBRTTarget(gcp,thisR,'replace',1);
fprintf('Added target, %d current targets\n',length(gcp.targets));

%% Change the sphere to glass

% For this scene, the BODY material is attached to ???? object.  We
% need to parse the geometry file to make sure.  This will happen, but
% has not yet.
target = thisR.materials.lib.plastic;    % Give it a chrome spd
rgbkr  = [0.5 0.5 0.5];              % Reflection
rgbkd  = [0.5 0.5 0.5];              % Scatter

piMaterialAssign(thisR, 'GLASS', target,'rgbkd',rgbkd,'rgbkr',rgbkr);
[p,n,e] = fileparts(fname);
oFile = sprintf('%s-2%s',n,e);
thisR.set('outputFile',fullfile(mcRootPath,'local','SimpleSceneExport',oFile));
piWrite(thisR,'creatematerials',true);

gcp.uploadPBRT(thisR,'materials',true,'geometry',false,'resources',false);  
addPBRTTarget(gcp,thisR,'replace',2);
fprintf('Added target, %d current targets\n',length(gcp.targets));

%% Render and then download

gcp.render();

cnt = 0;
while cnt < length(gcp.targets)
    pause(5);
    cnt = gcp.jobsStatus;
end

%%  You can get a lot of information about the job this way

%{
gcp.PodDescribe(podname{1})
gcp.Podlog(podname{1});
%}

%% Keep checking for the data, every 15 sec, and download it is there

scene   = gcp.downloadPBRT(thisR);
disp('Data downloaded');

% Show it in ISET
for ii = 1:length(scene) 
    ieAddObject(scene{ii});
end
sceneWindow;
sceneSet(scene,'gamma',0.5);

%% Remove all jobs
gcp.jobsDelete();

%%