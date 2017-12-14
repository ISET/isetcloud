%% Use gCloud to render multiple scenes with the PBRT V2 docker image
%
% This example shows how to render a PBRT scene on the kubernetes
% cluster.  This code uses the pbrt2ISET tools.  We explain at the end
% how render multiple scenes.
%
% Initialization
%   Make sure Docker and google SDK config are correct for your Matlab Env;
%   Initialize thr Gcloud cluster;
%
% Data definition
%  Identify the local scene data
%  Set pbrt rendering parameters;
%  Upload the files to the gcloud bucket;
%
% Run the rendering job
%
% Download the result (*.dat files) and read them into ISET;
% 
% Related toolboxes:  pbrt2ISET, ISET, matlab2cloud
%
% NOTES:
%  Cluster initialization time: around 5 mins.
%
% Typically, the renderings differ at least in their camera
% parameters.  For example, they may differ in the camera position.
% Also, they might differ in the lighting.  They may even have
% different resources (geometry files, spds, brdfs, ...)
%
%ZL, Vistalab 2017

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

%% Data definition
%
% The pbrt2ISET code will create a 'target' variable.  This contains
% the parameters 
% The task list is stored in the variable 'targets'
% if you want to assign a different job, ignore this for multi-tasks
%

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