%% Illustrate how to interact with the Google Cloud Platform
%
% This script illustrates local configuration, storage buckets,
% setting up a kubernetes cluster, removing a cluster
%
%
% See also: s_mcRender.m
% 
% ZL, BW, Vistasoft 2017

%% Make sure gcloud/gsutil/kubectl/docker are in your matlab env.

% Initialize ISET and verify that the 
ieInit;
if ~mcDockerExists, mcDockerConfig; end % check whether we can use docker
if ~mcGcloudExists, mcGcloudConfig; end % check whether we can use google cloud sdk;

%%  gCloud initialization 

% We are initializing a k8s cluster up on our account.  Also, we are
% setting the bucket where we store stuff.
%
% If the cluster named 'happyrendering' already exists, this will
% return in about 10 sec.  If the cluster is being created, then the
% startup is about 5 minutes.
tic;
dockerAccount= 'hblasins';
dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud';
cloudBucket = 'gs://primal-surfer-140120.appspot.com';
clusterName = 'happyrendering';

gcp = gCloud('dockerAccount',dockerAccount,...
    'dockerImage',dockerImage,...
    'cloudBucket',cloudBucket,...
    'clusterName',clusterName);
toc;

%% View google cloud configuration

gcp.Configlist;   % TODO - make the return format look a little nicer

%% list contents in the default or specified bucket 

gcp.ls  % Tells you which budkets you have

gcp.ls(cloudBucket)  % Lists the bucket contents

%% Creat a new bucket. 

% For more details on make bucket (mb) see
%
%  https://cloud.google.com/storage/docs/gsutil/commands/mb.
%
% The entire Google Cloud Storage has a single namespace, so you will
% not be allowed to create a bucket with a name already in use by
% another user.
%
% Note that bucketnames can contain only lowercase letters, numbers,
% dashes (-), and dots (.)  Further rules
%
% * Bucket names must start and end with a number or letter.
% * Bucket names must contain 3 to 63 characters. Names containing dots can
%   contain up to 222 characters, but each dot-separated component can be
%   no longer than 63 characters.
%
% This command gives you all the rules in selecting names. 
%
%    system('gsutil help naming')

bucket_new = 'gs://vistabucket';
gcp.bucketCreate(bucket_new);
gcp.ls 

%% Upload a file or a folder to vistabucket

% Can we upload a directory?
% Can we upload a cell array of file names

tic
localTestfile = fullfile(mcRootPath,'google','@gCloud','testfile.m');
remoteTestfile = gcp.upload(testfile,bucket_new);

readme = fullfile(mcRootPath,'README.md');
remoteReadme = gcp.upload(readme,bucket_new);

% This should return a cell array of file names
files = gcp.ls(bucket_new);

toc

%% Download the testfile.m from the vistabucket to the local directory

tic
cloudpath = fullfile(bucket_new,'testfile.m');
localpath = fullfile(mcRootPath,'local');
gcp.download(cloudpath, localpath);
dir(localpath)
toc

%% Remove the objects

gcp.rm(files{1}); gcp.ls(bucket_new)
gcp.rm(files{2}); gcp.ls(bucket_new)

%% remove a bucket
gcp.rm(bucket_new)
gcp.ls

%% Remove an existing cluster

gcp.clusterRm(clusterName);
gcp.Configlist;

%% Push one docker image from docker hub
% gcp.setDockerImage

%%  How do we shut down the k8s?

% This may be important for saving money!
% Something like cluster delete

%%
