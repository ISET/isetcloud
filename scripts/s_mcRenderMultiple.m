%% Use gCloud to render multiple scenes with the PBRT V3 docker image
%
% This extends the s_mcRender.m code to show how to build several
% variations of a scene. 
%
% We expect that you have already installed the isetcloud.and iset3d.  
%
% We anticipate that you will run this script by hand, section by section.
%   
% This function initializes a gcloud k8s cluster and executes the docker
% image with pbrt V3.
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
% Related toolboxes:  iset3d, isetcam, isetcloud
%
% NOTES:
%  The cluster initialization time: around 5 mins.
%
% ZL, Vistalab 2017

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

%% Multiple scene definitions

% The isetcloud code will upload an run a number of 'target' scenes, each
% defined by their own parameters. The list if targets is stored in the
% variable 'targets'.  We start out by emptying the list.

gcp.targets =[];

%% Set up the StopSign example

fname = fullfile(piRootPath,'data','V3','StopSign','stop.pbrt');
if ~exist(fname,'file'), error('File not found'); end

thisR = piRead(fname,'version',3);  % Some warnings here.
from = thisR.get('from');

% Default is a relatively low resolution (256).
thisR.set('camera','pinhole');
thisR.set('film resolution',256);
thisR.set('rays per pixel',128);

% Set up data for piWrite
outputDir = fullfile(mcRootPath,'local','stop');
if ~exist(outputDir,'dir'), mkdir(outputDir); end

[p,n,e] = fileparts(fname); 
thisR.outputFile = fullfile(outputDir,sprintf('%s-%d%s',n,1,e));
piWrite(thisR);

% Upload based on the recipe
gcp.uploadPBRT(thisR);

% This is always the first job
addPBRTTarget(gcp,thisR,'replace',1);
fprintf('Added one target.  Now %d current targets\n',length(gcp.targets));

%% Change the lookAt for the stop sign

% First dimension is right-left; second dimension is towards the object.
% The up direction is specified in lookAt.up
for jj=1:5
    
    % We move only a small amount so it looks a little like a video
    thisR.set('from',from + [0 0 jj/3]);
    thisR.outputFile = fullfile(outputDir,sprintf('%s-%d%s',n,jj+1,e));   
    piWrite(thisR);   % This lookAt case only modifies the scene file
    
    % Call this upload so all that we add is stop-2.pbrt, we do not upload the
    % geometry and materials and other stuff again.
    gcp.uploadPBRT(thisR,'material',false,'geometry',false,'resources',false);
    addPBRTTarget(gcp,thisR,'replace',jj+1);
    fprintf('Added target.  Now %d current targets\n',length(gcp.targets));
end

%% Describe the targets

gcp.targetsList;

%% This invokes the PBRT-V3 docker image
gcp.render();

cnt = 0;
while cnt < length(gcp.targets)
    cnt = podSucceeded(gcp);
    pause(5);
end

%{
podname = gcp.Podslist;
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
gcp.JobsRmAll();

%% END


