%% Upload training data to Cloud bucket and package tensorflow detection code

function obj = Traininit(obj, varargin )
% check if you are under the right project
cmd = sprintf('gcloud config get-value project');
[~, result] = system(cmd);
result = result(1:24);
if ~strcmp(result, obj.ProjectName)
    cmd = sprintf('gcloud config set project %s',obj.ProjectName);
    system(cmd);
end
%Upload data to cloudbucket

cmd = sprintf('gsutil cp %s gs://%s/%s/data/train.record', obj.Train_record, obj.cloudBucket,obj.namespace);
% [status, result]=system(cmd);
cmd = sprintf('gsutil cp %s gs://%s/%s/data/val.record', obj.Val_record,obj.cloudBucket,obj.namespace);
[status, result]=system(cmd);
cmd = sprintf('gsutil cp %s gs://%s/%s/data/label_map.pbtxt', obj.Label_map,obj.cloudBucket,obj.namespace);
[status, result]=system(cmd);
cmd = sprintf('gsutil cp %s/model.ckpt.* gs://%s/%s/data', obj.Pretrain_model, obj.cloudBucket,obj.namespace);
[status, result]=system(cmd);
%Edit the faster_rcnn_resnet101_pets.config template. Please note that there
%are multiple places where PATH_TO_BE_CONFIGURED needs to be set to the working dir.
cmd1=sprintf(' "s|PATH_TO_BE_CONFIGURED|"gs://%s/%s"/data|g" %s',...
obj.cloudBucket,obj.namespace,obj.NetworkConfig);
cmd=strcat('sed -i ''','''',cmd1);
[status, result]=system(cmd);
[~,network]=fileparts(obj.NetworkConfig);
cmd = sprintf('gsutil cp %s gs://%s/%s/data/%s.config', obj.NetworkConfig,...
    obj.cloudBucket,obj.namespace,network);
[status, result]=system(cmd);

% package Tensorflow Object Detection code
currentpath = pwd;
if ~exist(fullfile(gCT.TFmodels,'dist/object_detection-0.1.tar.gz'), 'file')
    cd (obj.TFmodels);
    cmd = sprintf('python setup.py sdist');
    [status, result]=system(cmd);
    cd(currentpath);
end
if ~exist(fullfile(gCT.TFmodels,'slim/dist/slim-0.1.tar.gz'), 'file')
    cd (obj.TFmodels);
    cd slim;
    cmd = sprintf('python slim/setup.py sdist');
    [status, result]=system(cmd);
    cd(currentpath);
end
end