%% Train on cloud

%% Initialization
if ~mcGcloudExists, mcGcloudConfig; end % check whether we can use google cloud sdk;
mcPythonConfig; % use the same python in terminal 

%% Data preparation
% set your path of google models, exp. '.../tensorflow/models/research' 
TFmodels = '/Users/zhenyiliu/git_repo/models/research';
% choose the project for training
ProjectName = 'machine-driving-20180115';
% ProjectName = 'primal-surfer-140120';
% set a cloud bucket to store all the training related files 
cloudBucket = 'machine-driving-20180115-ml';
% cloudBucket = 'deep_learning_20180520';	
% We can only us-east1 and us-central1  
region      = 'us-central1';% if "Internal error occurred for the current attempt" occured due to capacity crunch
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
% path to the dir where you want to save your trained model
localdir = '/Users/zhenyiliu/git_repo/isetcloud/local/checkpoint';

%% Training initialization
gCT = gCloudTrain('ProjectName',ProjectName,'cloudBucket',cloudBucket,...
    'TFmodels',TFmodels,'NetworkConfig',NetworkConfig,...
    'GPUconfig',GPUconfig,'Train_record', Train_record,'Val_record',Val_record,...
    'Label_map',Label_map,'Pretrain_model',Pretrain_model,'Task',Task,'localdir',localdir);
%% Train
gCT.train();

%% Evaluation
gCT.eval();

%% Monitor
gCT.monitor();

%% Fetch the trained model
% gCT.fetch()
% 
% %% Prediction
% Images_dir = 'Images_dir';
% gCT.predict(Images_dir)







