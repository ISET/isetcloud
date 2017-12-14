%% Use gCloud to render a scene with PBRT V2
%
% Add Docker and google SDK config to Matlab Env;
% Initialize your Gcloud cluster with customized configuration;
% Find your scene directory and set pbrt rendering parameters;
% Upload all the necessary files to the gcloud bucket;
% Render your scene;
% Download *.dat file and pass it to ISET;
% 
% NOTES:
%  Cluster initialization time: around 5 mins.
%
%ZL
%
%% Initialize ISET, Google cloud SDK and Docker

ieInit;
if ~mcDockerExists, mcDockerConfig; end % check whether we can use docker
if ~mcGcloudExists, mcGcloudConfig; end % check whether we can use google cloud sdk;

%% Initialize your cluster
tic
dockerAccount= 'hblasins';
dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud';
cloudBucket = 'gs://primal-surfer-140120.appspot.com';
clusterName = 'happyrendering';
gcp = gCloud('dockerAccount',dockerAccount,...
    'dockerImage',dockerImage,...
    'clusterName',clusterName,...
    'cloudBucket',cloudBucket);
toc
%% Clear current google task list if you want to assign a different job, ignore this for multi-tasks
gcp.targets =[];
%% Find the scene directory

fName = fullfile(mcRootPath,'data','teapot-area','teapot-area-light.pbrt');
thisR = piRead(fName);
thisR.set('camera','pinhole');
thisR.set('rays per pixel',32);
thisR.set('film resolution',256);
[p,n,e] = fileparts(fName); 
thisR.outputFile = fullfile(mcRootPath,'local',[n,e]);
piWrite(thisR);

%% Upload appropriately

gcp.uploadPBRT(thisR);

%% Invoke the render
gcp.render();

%% Return the data
scene   = gcp.downloadPBRT(thisR);
scene_1 = scene{1};

% Show it in ISET
vcAddObject(scene_1); sceneWindow;

%%