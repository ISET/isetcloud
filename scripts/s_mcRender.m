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
gcp.Configlist;

% This should be 'no resources found'
str = gcp.Podslist;

%% Data definition
%
% The isetcloud code creates a set of 'target' variables that describe the
% renderings we would like to perform.  We clear the variable at the start
% of this script.

% This will be 'jobs' some day.
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

% This should be gcp.addJob('pbrt',thisR);
% We might have other types of jobs in the future.
addPBRTTarget(gcp,thisR);
fprintf('Added one target.  Now %d current targets\n',length(gcp.targets));

%% This invokes the PBRT-V3 docker image

gcp.render();

cnt = 0;
while cnt < length(gcp.targets)
    [cnt, result] = podSucceeded(gcp);
    pause(5);
end

%{
%  You can get a lot of information about the job this way
podname = gcp.Podslist
gcp.PodDescribe(podname{1})
gcp.Podlog(podname{1});
%}

%% Download and show

scene   = gcp.downloadPBRT(thisR);
disp('Data downloaded');

% Show the first scene (there is only one in this case) in ISET
ieAddObject(scene{1}); sceneWindow;
sceneSet(scene,'gamma',0.5);

%% Remove all jobs - I am not really sure what this does.

% When we run a target job, it will create a kubernetes POD that may
% require a new Node.  For example, the PBRT target jobs ask for a resource
% that has 31 cores, and so a new Node is always created when we run a
% target job.
%
% Sometimes a job sits around and does not complete.  It is then restarted
% (by default) by kubernetes.  This always starts up a new Node.
%
% To clear out all the PODS (which are created by the targets/jobs) you can
% use this command.  I wonder if this should be labeled differently.  Maybe
% 'targets' should be 'jobs'.  Or maybe even PODS.
gcp.JobsRmAll();

%% END


