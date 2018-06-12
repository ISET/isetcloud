%% Use gCloud to render a scenes with the PBRT V3 docker image
%
% Shows how to render a PBRT scene on the kubernetes cluster.  This code
% uses the iset3d tools.
%
% We expect that you have already installed the isetcloud.and iset3d.  We
% do think that it will run all at once.  But that is less educational. The
% ideas in this script are described more fully on the isetcloud wiki page.
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
dockerAccount= 'vistalab';

% This is the docker image we use to render.  The gCloud code checks
% whether we have it, and if not it pulls from dockerhub to get it.
dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v3-spectral-gcloud';

% This is where data are stored.
cloudBucket = 'gs://primal-surfer-140120.appspot.com';

% A convenient name for reference
clusterName = 'pbrtcloud';

% The Wandell lab has two projects.  For rendering we use this one.
projectid    = 'primal-surfer-140120';

% These can be set, and here are the defaults
% zone         = 'us-central1-a';    
% instanceType = 'n1-highcpu-32';

gcp = gCloud('dockerAccount',dockerAccount,...
    'projectid',projectid,...
    'dockerImage',dockerImage,...
    'clusterName',clusterName,...
    'cloudBucket',cloudBucket);
toc

%%
% This prints out a summary of the situation.  The command returns a struct
% with the various fields, as well.
str = gcp.Configlist;

%% Data definition
%
% The pbrt2ISET code will create a 'target' variable.  This contains
% the parameters 
% The task list is stored in the variable 'targets'
% if you want to assign a different job, ignore this for multi-tasks
%

gcp.targets =[];

%% This is the teapot example in iset3d

fName = fullfile(piRootPath,'data','teapot-area','teapot-area-light.pbrt');
thisR = piRead(fName);
thisR.set('camera','pinhole');
thisR.set('rays per pixel',32);
thisR.set('film resolution',256);
[p,n,e] = fileparts(fName); 
thisR.outputFile = fullfile(mcRootPath,'local','teapot',[n,e]);
piWrite(thisR);

%% This is the StopSign example in iset3d

%{
fname = fullfile(piRootPath,'data','V3','StopSign','stop.pbrt');
if ~exist(fname,'file'), error('File not found'); end

thisR = piRead(fname,'version',3);  % Some warnings here.
from = thisR.get('from');

% Default is a relatively low resolution (256).
thisR.set('camera','pinhole');
thisR.set('from',from + [0 0 100]);  % First left/right, 2nd moved camera closer and to the right 
thisR.set('film resolution',256);
thisR.set('rays per pixel',128);

% Set up data for upload
outputDir = fullfile(piRootPath,'local','stop');
if ~exist(outputDir,'dir'), mkdir(outputDir); end

[p,n,e] = fileparts(fname); 
thisR.outputFile = fullfile(outputDir,[n,e]);
piWrite(thisR);
%}

%% Upload to the bucket attached to pbrtrendering

% This zips all the files needed for rendering into a single file. Then the
% zip file and the critical pbrt scene file is uploaded to the bucket.
gcp.uploadPBRT(thisR);

%{
   % You can list the files in your own part of the bucket this way
   gcp.ls('print',true,'folder','wandell');
%}
%% Add the new PBRT rendering target with necessary information

% After the upload, the target slot has the information needed to
% render
if ~isempty(gcp.targets)
    fprintf('%d current targets\n',length(gcp.targets));
end

addPBRTTarget(gcp,thisR);
fprintf('Added one target.  Now %d current targets\n',length(gcp.targets));

%% This invokes the PBRT-V3 docker image
gcp.render();

%%  You can get a lot of information about the job this way

%{
[~,~,~,podname] = gcp.Podslist();
gcp.PodDescribe(podname{1})
gcp.Podlog(podname{1});
%}

%% Keep checking for the data, every 5 sec, and download it is there

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
ieAddObject(scene_1); sceneWindow;
sceneSet(scene,'gamma',1);

%% Remove all jobs
gcp.JobsRmAll();

%% END


