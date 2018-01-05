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
clusterName = 'pbrtrendering';
zone         = 'us-west1-a';    %'us-central1-a';
instanceType = 'n1-highcpu-32';
gcp = gCloud('dockerAccount',dockerAccount,...
    'dockerImage',dockerImage,...
    'clusterName',clusterName,...
    'cloudBucket',cloudBucket,'zone',zone,'instanceType',instanceType);
toc
gcp.Configlist;
%% Data definition
%
% The pbrt2ISET code will create a 'target' variable.  This contains
% the parameters 
% The task list is stored in the variable 'targets'
% if you want to assign a different job, ignore this for multi-tasks
%

gcp.targets =[];

%% Find the scene directory in pbrt2ISET

%{
fName = fullfile(piRootPath,'data','teapot-area','teapot-area-light.pbrt');
thisR = piRead(fName);
thisR.set('camera','pinhole');
thisR.set('rays per pixel',32);
thisR.set('film resolution',256);
[p,n,e] = fileparts(fName); 
thisR.outputFile = fullfile(mcRootPath,'local','teapot',[n,e]);
piWrite(thisR);
%}
%
fname = fullfile(piRootPath,'data','ChessSet','chessSet.pbrt');
if ~exist(fname,'file'), error('File not found'); end

% Read the main scene pbrt file.  Return it as a recipe
thisR = piRead(fname);
from = thisR.get('from');

%%Default is a relatively low resolution (256).
thisR.set('camera','pinhole');
thisR.set('from',from + [0 0 100]);  % First left/right, 2nd moved camera closer and to the right 
thisR.set('film resolution',256);
thisR.set('rays per pixel',128);

% Set up data for upload
outputDir = fullfile(piRootPath,'local','chess');
if ~exist(outputDir,'dir'), mkdir(outputDir); end

[p,n,e] = fileparts(fname); 
thisR.outputFile = fullfile(outputDir,[n,e]);
piWrite(thisR);
%}

%% Upload to the bucket attached to pbrtrendering

% This first zips all the files into a single file. Then the zip file
% and the critical pbrt scene file is uploaded to the bucket.
gcp.uploadPBRT(thisR);

% gcp.ls(fullfile(gcp.cloudBucket,'wandell','chessSet'))

%% Add the new PBRT rendering target with necessary information

% After the upload, the target slot has the information needed to
% render
if ~isempty(gcp.targets)
    fprintf('%d current targets\n',length(gcp.targets));
end

addPBRTTarget(gcp,thisR);
fprintf('Added one target.  Now %d current targets\n',length(gcp.targets));

%% This invokes the PBRT-V2 docker image
gcp.render();
% Check jobs status
gcp.checkJobs('namespace',gcp.namespace);

%% Return the data



scene = [];
while isempty(scene)
    try
        scene   = gcp.downloadPBRT(thisR);
        disp('Data downloaded');
    catch
        pause(5);
    end
end
scene_1 = scene{1};

% Show it in ISET
vcAddObject(scene_1); sceneWindow;
sceneSet(scene,'gamma',1); 

%%  Now, change the lookat (twice) and render all three

% Camera position
from = thisR.get('from');
dFrom = zeros(6,3);
dFrom(:,1) = linspace(-20,15,6);

% Clear the target operations
gcp.targets = [];

% Get the basename and extension
basename = thisR.get('input base name');
ext = '.pbrt';
outdir = fileparts(thisR.outputFile);
%% Upload the pbrt scene files

% These will be the names of the various pbrt scene files
files = cell(size(dFrom,1),1);
for ii=1:size(dFrom,1)
    
    % Create the adjusted pbrt scene file
    thisR.set('from',from + dFrom(ii,:));
    files{ii} = fullfile(outdir,[sprintf('%s-%d',basename,ii),ext]);
    thisR.outputFile = files{ii};
    piWrite(thisR,'overwrite resources',false);
    
    % Upload just the scene file
    if ii == 1, [cloudFolder,zipFileName] = gcp.uploadPBRT(thisR);
    else,       gcp.uploadPBRT(thisR,'upload zip',false,'overwrite zip',false);
    end
    
    % Add the new target operation
    addPBRTTarget(gcp,thisR);
end

%% Confirm the uploaded pbrt scene files and zip with resources

gcp.ls(cloudFolder)

%% Call the job scheduler

gcp.render();

%% Show the running jobs

% Maybe we could use this method to check the jobs
v = gcp.listJobs;

%%  The download checks the number of targets and downloads a file for each 
scene = gcp.downloadPBRT(thisR);
nTargets = length(gcp.targets);
for ii=1:nTargets
    vcAddObject(scene{ii});
end
sceneWindow;
sceneSet(scene{ii},'gamma',1);

%% Show it in ISET


