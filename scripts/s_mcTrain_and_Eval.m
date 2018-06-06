%% Train and evaluate a tensorflow model on Google cloud
%
% We illustrate how to 
%
%   * Specify the Google Cloud project information
%   * 
% 
% ZL Vistasoft team, 2018

%% Initialization

% check whether we can use google cloud sdk;
if ~mcGcloudExists, mcGcloudConfig; end 

% use the same python in terminal 
if mcPythonExists, mcPythonConfig; end

%% Project specification

% choose the project for training
ProjectName = 'machine-driving-20180115';
% ProjectName = 'primal-surfer-140120';

% set a cloud bucket to store all the training related files 
cloudBucket = 'machine-driving-20180115-ml';
% cloudBucket = 'deep_learning_20180520';

% We can only use us-east1 and us-central1 because of resource issues
% if "Internal error occurred for the current attempt" occured due to
% capacity crunch 
region      = 'us-central1';

%% Make sure the tensorflow models are present in your local copy

% Store google tensorflow models git hub repository
TFmodels = fullfile(mcRootPath,'local','models','research');
if ~exist(TFmodels,'dir')
    chdir(fullfile(mcRootPath,'local'));
    system('git clone https://github.com/tensorflow/models.git');
end

%% Set a path to the configured network

NetworkConfig = fullfile(TFmodels,'object_detection','samples','configs','faster_rcnn_resnet101_coco.config');

%{
 % If you would like to edit the configuration parameters and try some
 % network experiments, do something like this
 newConfig = fullfile(TFmodels,'object_detection','samples','configs','faster_rcnn_resnet101_coco.config');
 copy(NetWorkConfig,newConfig);
 NetWorkConfig = newConfig;
%}

% path to GPU configuration file for the training
GPUconfig=fullfile(TFmodels,'object_detection','samples','cloud','cloud.yml');

%% Data and labels

% We store these relatively large data sets up on the AWS RemoteData
% client.  The first time you might have to download them.
localData = fullfile(mcRootPath,'local','datasets');

aName = 'bdd0525';
Train_record = fullfile(mcRootPath,'local','datasets',[aName,'_train.tfrecord']);
Val_record   = fullfile(mcRootPath,'local','datasets',[aName,'_val.tfrecord']);

if ~exist(Train_record,'file') || ~exist(Val_record,'file')
    fprintf('Could not find train or val record.  Downloading and installing');
    rdt = RdtClient('isetbio');
    rdt.crp('/resources/driving/bdd');
    a = rdt.searchArtifacts(aName);
    [fnameZIP, artifact] = rdt.readArtifact(a(1),'destinationFolder',localData);
    unzip(fnameZIP);
end

% bdd uses the same labels as kitti.  Other models might use different
% labels.
Label_map = fullfile(TFmodels,'object_detection','data','kitti_label_map.pbtxt');
Task = 'bdd_evalonKitti_SSD';

%% Download the pre-trained model if you don't have it already
pretrain_dir = fullfile(mcRootPath,'local','pretrained');
if ~exist(pretrain_dir,'dir')
    fprintf('Making pretrained directory\n');
    mkdir(fullfile(mcRootPath,'local','pretrained'));
end
chdir(pretrain_dir);

% This is the directory with the pretrained model stored in the model
% zoo web site.
% https://github.com/tensorflow/models/blob/master/research/object_detection/g3doc/detection_model_zoo.md
url = 'http://download.tensorflow.org/models/object_detection/faster_rcnn_resnet101_coco_2018_01_28.tar.gz';
[~,n,~] = fileparts(url);
[~,Pretrain_model,~] = fileparts(n);
Pretrain_model = fullfile(pretrain_dir,Pretrain_model);
if ~exist(Pretrain_model,'dir')
    gunzip(url);   % Produces a tar file
    untar(n);
end

%% Store the checkpoints here

% path to the dir where you want to save your trained model
localdir = fullfile(mcRootPath,'local','checkpoint');
if ~exist(localdir,'dir')
    mkdir(localdir);
end

%%  Initialize the object for training

% See the tips here
%    https://github.com/ISET/isetcloud/tree/master/google_ml
% Remember the tip - for now we need to manually place pycocotools
% into the research/models/object_detection directory.  Hopefully this
% will not be necessary in the near future. 

% Also, you should have a look at the config file.  In general, people
% want to edit the config file for the parameters they want set for
% training. 
%
% There is one critical matter you must do.  The input_path and the
% label_path for both the training and the eval sections need to have
% generic names of train.record and val.record.  By default these
% files have some stuff pre-prended (elgl, mscoco_train.record.  We
% still need to edit these by hand.  At some point we will figure out
% how to automate this.  Last thing!
%{
edit(NetworkConfig)
%}

% This command copies the data to the remote buckets and builds the
% google cloud traijning oject.
gCT = gCloudTrain('ProjectName',ProjectName,...
    'cloudBucket',cloudBucket,...
    'TFmodels',TFmodels,...
    'NetworkConfig',NetworkConfig,...
    'GPUconfig',GPUconfig,...
    'Train_record', Train_record,...
    'Val_record',Val_record,...
    'Label_map',Label_map,...
    'Pretrain_model',Pretrain_model,...
    'Task',Task,...
    'localdir',localdir);

% You can check the cloudBucket on the console to see that the data
% have been uploaded.

%% Start the training

% You start the training and every so often the training saves the
% checkpoint file so you can evaluate.
gCT.train();

% You will get a little 'submitted' job response back

% To stop this process, we must go to the console page and stop it
% manually.  The stop can take a few minutes.  We are looking for a
% command to stop the job.  Since we are checking the job on the
% console anyway, this hasn't really bugged ZL.  

%% Evaluation

% Once there is a checkpoint file, you can evaluate.
gCT.eval();

%% Monitor

% This should use the google console to monitor training.  But there
% is a known Google bug at this time.  So we don't use it yet.  This
% is a tensor board issue.  It worked last year, and it will work
% again some day.
gCT.monitor();

%% Fetch the trained model

% When you are done, you can get the trained model this way
% gCT.fetch()

% You can make predictions for held out images this way
% Images_dir = 'Images_dir';
% gCT.predict(Images_dir)

%%

%{
% To store the data, we do this
rdt = RdtClient('isetbio');
rdt.credentialsDialog;
rdt.crp('/resources/driving/bdd');
chdir(fullfile(mcRootPath,'local','datasets'));
fnameZIP = 'bdd0525.zip';
[~,fname,ext] = fileparts(fnameZIP);
rdt.publishArtifact(fnameZIP,...
   'version','1',...
   'name',fname);
rdt.listArtifacts('print',true);
rdt.browse;
%}

%{
=======
% path to the configured network
NetworkConfig = fullfile(TFmodels,'object_detection/samples/configs/faster_rcnn_resnet101_bdd.config');
% path to GPU configuration file
GPUconfig=fullfile(TFmodels,'object_detection/samples/cloud/cloud.yml');
% prepare your train.record and val.record files
Train_record = '/Users/zhenyiliu/git_repo/isetcloud/local/datasets/bdd-kitti_car_truck_ped/bdd0525_train.tfrecord';
Val_record = '/Users/zhenyiliu/git_repo/isetcloud/local/datasets/bdd-kitti_car_truck_ped/bdd0525_val.tfrecord';
Label_map = '/Users/zhenyiliu/git_repo/models/research/object_detection/data/kitti_label_map.pbtxt';
% Provide a task name
Task = 'bdd_FasterRCNN';
%paht to pre-trained model
Pretrain_model = '/Users/zhenyiliu/git_repo/isetcloud/local/datasets/pretrained_models/faster_rcnn_resnet101_coco_2018_01_28';
>>>>>>> 7846c11cca469fb7798eb1b8544888e624724570
%}