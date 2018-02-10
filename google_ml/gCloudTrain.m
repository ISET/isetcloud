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
       Task           ='';
       localdir       ='';
       Cloudfolder;
      
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
            p.addParameter('Task','',@ischar);
            p.addParameter('localdir','',@ischar);
            
            p.parse(varargin{:});
            
            obj.ProjectName   = p.Results.ProjectName;
            obj.cloudBucket   = p.Results.cloudBucket;
            obj.region        = p.Results.region;
            obj.TFmodels      = p.Results.TFmodels;
            obj.NetworkConfig = p.Results.NetworkConfig;
            obj.GPUconfig       = p.Results.GPUconfig;
            obj.Train_record  = p.Results.Train_record;
            obj.Val_record    = p.Results.Val_record;
            obj.Label_map     = p.Results.Label_map;
            obj.Pretrain_model= p.Results.Pretrain_model;
            obj.Task          = p.Results.Task;
            obj.localdir      = p.Results.localdir;
            [~, obj.namespace] = system('echo -n $USER');
            obj.Cloudfolder = sprintf('gs://%s/%s/%s',obj.cloudBucket,obj.namespace,obj.Task);
            Traininit(obj);
        
        end
        
        
        function [result, status, cmd] = train(obj)
            [~,Network]=fileparts(obj.NetworkConfig);
            rand = num2str(randi(1000));
            cmd = sprintf('gcloud ml-engine jobs submit training %s_object_detection_%s --runtime-version 1.2 --job-dir=%s/train --packages %s/dist/object_detection-0.1.tar.gz,%s/slim/dist/slim-0.1.tar.gz --module-name object_detection.train --region %s --config %s -- --train_dir=%s/train --pipeline_config_path=%s/data/%s.config',...
                obj.Task,rand,obj.Cloudfolder,obj.TFmodels,obj.TFmodels,...
                obj.region,obj.GPUconfig,obj.Cloudfolder,obj.Cloudfolder, Network);
            [status, result]=system(cmd);
            fprintf(result);
        end
        
        function [result, status, cmd] = eval(obj)
            [~,Network]=fileparts(obj.NetworkConfig);
            rand = num2str(randi(1000));
            cmd = sprintf('gcloud ml-engine jobs submit training %s_object_detection_eval_%s --runtime-version 1.2 --job-dir=%s/train --packages %s/dist/object_detection-0.1.tar.gz,%s/slim/dist/slim-0.1.tar.gz --module-name object_detection.eval --region %s --scale-tier BASIC_GPU -- --checkpoint_dir=%s/train --eval_dir=%s/eval --pipeline_config_path=%s/data/%s.config',...
                obj.Task,rand,obj.Cloudfolder,obj.TFmodels,obj.TFmodels,...
                obj.region,obj.Cloudfolder,obj.Cloudfolder,obj.Cloudfolder, Network);
            [status, result]=system(cmd);
            fprintf(result);
        end
        
        function [result, status, cmd] = monitor(obj)
            url = 'http://localhost:6006';%tensorboard.
            web(url,'-browser');
            cmd = sprintf('tensorboard --logdir= %s',obj.Cloudfolder);
            [status, result]=system(cmd);

        end
%         function [result, status, cmd] = checkpoint(obj)
%             cmd = sprintf('gsutil ls  %s/%s/%s/tain/*.meta');
%             [~,result] = system(cmd);
%             fpirntf(result);
%         end
        % Fetch the latest trained model
        function [result, status, cmd] = fetch(obj)
            
            cmd = sprintf('gsutil ls  %s/train/*.meta',obj.Cloudfolder);
            [~,filename] = system(cmd);
            file = regexprep(filename,'gs://machine-driving-20180115-ml/eugeneliu/','');
            file = regexprep(file,'.meta','');
            file_num = regexp(file,'\d*','Match');
            for i = 1:length(file_num)
                file(:,i)=str2double(file_num{i});
            end
            file_num = max(file);
            cmd = sprintf('gsutil cp %s/train/mode.ckpt-%s %s',obj.Cloudfolder,file_num,obj.localdir);
            system(cmd);
            cmd = sprintf('gsutil cp %s/train/pipeline.config %s',obj.Cloudfolder,obj.localdir);
            [status, result] = system(cmd);
            
        end
        
        % Predict the result by given images
        function [result, status, cmd] = predict(obj,img_dir)
            % convert model to inference graph
            cmd = sprintf('python object_detection/export_inference_graph.py --input_type image_tensor --pipeline_config_path %s --trained_checkpoint_prefix %s --output_directory %s/frozen_inference_graph.pb',...
                obj.localdir,obj.localdir,obj.localdir);
            [status, result] = system(cmd);
            DetectionGraph = fullfile('%s/frozen_inference_graph.pb',obj.localdir);
            % configure file paths for detection scripts
            
            DetectionGraph = fullfile('%s/frozen_inference_graph.pb',obj.localdir);
            obj_det = fullfile(mcRootPath,'object_detection.py');
            cmd1=sprintf(' "s|PATH_TO_LABEL|"%s"|g" %s',...
                obj.Label_map,obj_det);
            cmd=strcat('sed -i ''','''',cmd1);
            [status, result]=system(cmd);
            
            cmd1=sprintf(' "s|DetectionGraph|"%s"|g" %s',...
                DetectionGraph,obj_det);
            cmd=strcat('sed -i ''','''',cmd1);
            [status, result]=system(cmd);
            
             cmd1=sprintf(' "s|PATH_TO_TEST_IMAGES_DIR|"%s"|g" %s',...
                img_dir,obj_det);
            cmd=strcat('sed -i ''','''',cmd1);
            [status, result]=system(cmd);
            % predict model
            cmd = sprintf('python %s',obj_det);
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


   
    