%% Small test script to evaluate whether we got the cloud set up right
%
% ZL, BW
%% Add gcloud/gsutil/kubectl/docker functions in your matlab env.
mcConfig;
%%  Initialization
dockerAccount= 'hblasins';
dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud';
cloudBucket = 'gs://primal-surfer-140120.appspot.com';
gcp = gCloud('dockerImage',dockerImage,'cloudBucket',cloudBucket);
%% View google cloud configuration
gcp.Configlist;
%% list contents in the default or specified bucket 
gcp.ls
gcp.ls(cloudBucket)
%% Creat a new bucket. For more detail: https://cloud.google.com/storage/docs/gsutil/commands/mb.
bucket_new = 'gs://vistabucket';
gcp.bucketCreate(bucket_new);
%% Upload a file or a folder
fName = '/Users/eugeneliu/git_repo/matlab2cloud/google/@gCloud/testfile.m';
gcp.upload(fName,bucket_new);
fName_cloud=gcp.ls(bucket_new);
%% Download a file
cloudpath = fullfile(bucket_new,'/','testfile.m');
localpath = pwd;
gcp.download(cloudpath, localpath);
%% remove an object
gcp.rm(fName_cloud)
gcp.ls(bucket_new)
% remove a bucket
gcp.rm(bucket_new)
gcp.ls
%% Push one docker image from docker hub
% gcp.setDockerImage
%% Render a scene; Todo: render 
fName = fullfile('/','home','hblasins','City','001_city_1_placement_1_radiance.pbrt');
% workdir = fullfile('/','scratch','hblasins','pbrt2ISET','City');
% if exist(workdir,'dir') == false,
%     mkdir(workdir);
% end
% 
% scene = piRead(fName);
% scene.set('rays per pixel',32);
% 
% d = fileparts(fName);
% scene.set('outputFile',fullfile(workdir,'city.pbrt'));
% piWrite(scene);


gcp.upload(scene);
gcp.render();
gcp.download();
