%% Train on cloud

%% Initialization
if ~mcGcloudExists, mcGcloudConfig; end % check whether we can use google cloud sdk;
mcPythonConfig; % use the same python in terminal 

%% Data preparation

% set your path of google models, exp. '.../tensorflow/models/research' 
TFmodels = '/Users/eugeneliu/git_repo/tensorflow/models/research';
% choose the project for training
ProjectName = 'machine-driving-20180115';
% set a cloud bucket to store all the training related files 
cloudBucket = 'machine-driving-20180115-ml';
% We can only us-east1 and us-central1  
region      = 'us-east1';% if "Internal error occurred for the current attempt" occured due to capacity crunch
% path to the configured network
NetworkConfig = fullfile(TFmodels,'object_detection/samples/configs/ssd_mobilenet_v1_pinhole.config');
% path to GPU configuration file
GPUconfig=fullfile(TFmodels,'object_detection/samples/cloud/cloud.yml');
% prepare your train.record and val.record files
Train_record = '/Users/eugeneliu/Desktop/sRGB_aeMean_0.4_EV_mix_trainval.record';
Val_record = '/Users/eugeneliu/Desktop/sRGB_aeMean_0.4_EV_mix_test.record';
Label_map = '/Users/eugeneliu/Downloads/MultiObject-Pinhole_label_map.pbtxt';
Task = 'sRBG_mix';
%paht to pre-trained model
Pretrain_model = '/Users/eugeneliu/git_repo/tensorflow/pretrained_models/ssd_mobilenet_v1_coco_2017_11_17';

%% Training initialization
gCT = gCloudTrain('ProjectName',ProjectName,'cloudBucket',cloudBucket,...
    'TFmodels',TFmodels,'NetworkConfig',NetworkConfig,...
    'GPUconfig',GPUconfig,'Train_record', Train_record,'Val_record',Val_record,...
    'Label_map',Label_map,'Pretrain_model',Pretrain_model,'Task',Task);
%% Train
gCT.train();

%% Evaluation
gCT.eval();
%% Monitor, 
gCT.monitor();





