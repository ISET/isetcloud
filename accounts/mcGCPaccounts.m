% List all the name spaces currently on the cluster

gcpconfig.dockerAccount= 'vistalab';

% This is the docker image we use to render.  The gCloud code checks
% whether we have it, and if not it pulls from dockerhub to get it.
gcpconfig.dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v3-spectral-flywheel';

% This is where data are stored.
gcpconfig.cloudBucket = 'gs://primal-surfer-140120.appspot.com';

% A convenient name for reference
gcpconfig.clusterName = 'cloudrendering';

% The Wandell lab has two projects.  For rendering we use this one.
gcpconfig.projectid    = 'primal-surfer-140120';


% These can be set, and here are the defaults
gcpconfig.zone         = 'us-central1-b';    
% gcpconfig.instanceType = 'n1-highcpu-32';
gcpconfig.instanceType = 'n1-standard-32';

jsonName = fullfile(mcRootPath,'accounts','cloudRendering-pbrtv3-central-standard-32cpu-120m-flywheel.json');
jsonwrite(jsonName,gcpconfig);

%{
thisAccount = jsonread(jsonName);
%}
%%