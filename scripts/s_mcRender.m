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
gCloud('configuration','gcp-pbrtv3-central-32');
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

%% Upload to the bucket attached to pbrtrendering

% This zips all the files needed for rendering into a single file. Then the
% zip file and the critical pbrt scene file is uploaded to the bucket.
gcp.uploadPBRT(thisR);

%{
   % You can list the files in your own part of the bucket this way
   gcp.ls('print',true,'folder','wandell');
   gcp.ls('print',true,'folder','wandell/teapot-area-light');
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

cnt = 0;
while cnt < length(gcp.targets)
    cnt = podSucceeded(gcp);
    pause(5);
end

%{
%  You can get a lot of information about the job this way
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
sceneSet(scene,'gamma',0.5);

%% Remove all jobs
gcp.JobsRmAll();

%% END


