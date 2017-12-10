%% Use gCloud to render a scene with PBRT V2
%
% ZL
%

%% Create your cluster

dockerAccount= 'hblasins';
dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud';
cloudBucket = 'gs://primal-surfer-140120.appspot.com';
clusterName = 'happyrendering';
gcp = gCloud('dockerAccount',dockerAccount,...
    'dockerImage',dockerImage,...
    'clusterName',clusterName,...
    'cloudBucket',cloudBucket);

%% Find the scene directory

% 
% scene = piRead(fName);
% scene.set('rays per pixel',32);
% 
% d = fileparts(fName);
% scene.set('outputFile',fullfile(workdir,'city.pbrt'));
% piWrite(scene);

%% Upload appropriately

gcp.uploadPBRT(thisR);

%% Invoke the render
gcp.render();

%% Return the data
gcp.download();

%%