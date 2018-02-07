classdef gCloudTrain < handle
    % List functions for training on cloud
   properties (GetAccess=public, SetAccess=public)
       region         = 'us-central1';
       ProjectName    = 'machine-driving-20180115';
       cloudBucket    =''; 
       TFmodels       ='';
       NetworkConfig  ='';
       GPUconfig      ='';
       Train_record   ='';
       Val_record     ='';
       Label_map      ='';
       namespace      ='';
       Pretrain_model ='';
       
   end
    
    methods
        function obj = gCloudTrain(varargin)
            p = inputParser;
            
            p.addParameter('ProjectName','machine-driving-20180115',@ischar);
            p.addParameter('cloudBucket','',@ischar);
            p.addParameter('region','us-central1',@ischar);

            p.addParameter('TFmodels','',@ischar);
            p.addParameter('NetworkConfig','',@ischar);
            p.addParameter('GPUconfig','',@ischar);
            p.addParameter('Train_record','',@ischar);
            p.addParameter('Val_record','',@ischar);
            p.addParameter('Label_map','',@ischar);
            p.addParameter('Pretrain_model','',@ischar);

            
            p.parse(varargin{:});
            
            obj.ProjectName  = p.Results.ProjectName;
            obj.cloudBucket  = p.Results.cloudBucket;
            obj.region       = p.Results.region;
            obj.TFmodels     = p.Results.TFmodels;
            obj.NetworkConfig= p.Results.NetworkConfig;
            obj.GPUconfig       = p.Results.GPUconfig;
            obj.Train_record = p.Results.Train_record;
            obj.Val_record   = p.Results.Val_record;
            obj.Label_map    = p.Results.Label_map;
            obj.Pretrain_model = p.Results.Pretrain_model;
            
            [~, obj.namespace] = system('echo -n $USER');

            Traininit(obj);
        
        end
        
        
        function [result, status, cmd] = train(obj)
            [~,Network]=fileparts(obj.NetworkConfig);
            rand = num2str(randi(1000));
            cmd = sprintf('gcloud ml-engine jobs submit training %s_object_detection_%s --runtime-version 1.2 --job-dir=gs://%s/%s/train --packages %s/dist/object_detection-0.1.tar.gz,%s/slim/dist/slim-0.1.tar.gz --module-name object_detection.train --region %s --config %s -- --train_dir=gs://%s/%s/train --pipeline_config_path=gs://%s/%s/data/%s.config',...
                obj.namespace,rand,obj.cloudBucket,obj.namespace,obj.TFmodels,obj.TFmodels,...
                obj.region,obj.GPUconfig,obj.cloudBucket,obj.namespace,obj.cloudBucket,obj.namespace, Network);
            [status, result]=system(cmd);
            fprintf(result);
        end
        
        function [result, status, cmd] = eval(obj)
            [~,Network]=fileparts(obj.NetworkConfig);
            rand = num2str(randi(1000));
            cmd = sprintf('gcloud ml-engine jobs submit training %s_object_detection_eval_%s --runtime-version 1.2 --job-dir=gs://%s/%s/train --packages %s/dist/object_detection-0.1.tar.gz,%s/slim/dist/slim-0.1.tar.gz --module-name object_detection.eval --region %s --scale-tier BASIC_GPU -- --checkpoint_dir=gs://%s/%s/train --eval_dir=gs://%s/%s/eval --pipeline_config_path=gs://%s/%s/data/%s.config',...
                obj.namespace,rand,obj.cloudBucket,obj.namespace,obj.TFmodels,obj.TFmodels,...
                obj.region,obj.cloudBucket,obj.namespace,obj.cloudBucket,obj.namespace,obj.cloudBucket,obj.namespace, Network);
            [status, result]=system(cmd);
            fprintf(result);
        end
        
        function [result, status, cmd] = monitor(obj)
            url = 'http://localhost:6006';%tensorboard.
            web(url,'-browser');
            cmd = sprintf('tensorboard --logdir=gs://%s/%s',obj.cloudBucket,obj.namespace);
            [status, result]=system(cmd);

        end
        % list contents in bucket, a function from gcloud
        function [result, status, cmd] = ls(obj,bucketname)
            if notDefined('bucketname')
                cmd = sprintf('gsutil ls');
                [status,result] = system(cmd);
            else
                d = bucketname;
                cmd = sprintf('gsutil ls %s\n',d);
                [status,result] = system(cmd);
            end
            
            if ~isempty(result)
                % Converts the char array return to a cell array
                files = split(result);
                ispresent = cellfun(@(s) ~isempty(s), files);
                result = files(ispresent);
            end
            
        end
        
    end
end


   
    