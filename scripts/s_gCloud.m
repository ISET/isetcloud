%% Illustrate how to interact with the Google Cloud Platform
% For render task, see s_mcRender.m
% 
% ZL, BW

%% Add gcloud/gsutil/kubectl/docker functions in your matlab env.
mcConfig;

%%  Initialization
tic;
% Set up to run the PBRT V2 docker image
dockerAccount= 'hblasins';
dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud';
cloudBucket = 'gs://primal-surfer-140120.appspot.com';
clusterName = 'happyrendering';
% We are initializing a k8s cluster up on our account.  Also, we are
% setting the bucket where we store stuff.
gcp = gCloud('dockerAccount',dockerAccount,...
    'dockerImage',dockerImage,...
    'cloudBucket',cloudBucket,...
    'clusterName',clusterName);
toc;
%% View google cloud configuration

gcp.Configlist;
%% Remove an existing cluster

gcp.clusterRm(clusterName);
gcp.Configlist;
%% list contents in the default or specified bucket 

gcp.ls  % Tells you which budkets you have

gcp.ls(cloudBucket)  % Lists the bucket contents

%% Creat a new bucket. 

% For more details on make bucket (mb) see
%  https://cloud.google.com/storage/docs/gsutil/commands/mb.
%
% Google Cloud Storage has a single namespace, so you will not be
% allowed to create a bucket with a name already in use by another
% user.
%
%  Note that bucketnames can contain only lowercase letters, numbers,
%   dashes (-), and dots (.)
%  Bucket names must start and end with a number or letter.
%  Bucket names must contain 3 to 63 characters. Names containing dots can
%   contain up to 222 characters, but each dot-separated component can be
%   no longer than 63 characters.
%
% This command gives you all the rules in selecting names. 
%    system('gsutil help naming')

bucket_new = 'gs://vistabucket';

gcp.bucketCreate(bucket_new);

gcp.ls 

%% Upload a file or a folder

fName = fullfile(mcRootPath,'google','@gCloud','testfile.m');
gcp.upload(fName,bucket_new);
fName_cloud = gcp.ls(bucket_new);

%% Download a file

cloudpath = fullfile(bucket_new,'testfile.m');
localpath = fullfile(mcRootPath,'local');
gcp.download(cloudpath, localpath);
dir(localpath)

%% remove an object
gcp.rm(fName_cloud)
gcp.ls(bucket_new)

%% remove a bucket
gcp.rm(bucket_new)
gcp.ls

%% Push one docker image from docker hub
% gcp.setDockerImage

%%  How do we shut down the k8s?

% This may be important for saving money!
% Something like cluster delete

%%
