classdef gCloud < handle
% Interface from Matlab to Google Cloud Platform
%
% Syntax
%   gcp = gCloud(...)
%
% ZL/BW 

    properties (GetAccess=public, SetAccess=public)
        
        % Local folder in the docker image
        localFolder = 'WorkDir';
        cloudBucket = '';
        
        % where to write output files
        outputFolder;
        
        % where to put scenes before rendering
        workingFolder;
        
        % Variables specific to cloud provider
        provider     = 'Google';
        clusterName  = 'rtb4';
        zone         = 'us-central1-a';
        instanceType = 'n1-highcpu-32';
        minInstances = 1;
        maxInstances = 10;
        preemptible  = true;
        autoscaling  = true;
        namespace    = '';
        
        dockerImage  = '';
        dockerAccount= '';
        
        targets;
        
    end
    
    methods
       
        % Constructor and gcloud cluster initialization.
        function obj = gCloud(varargin)
            
            p = inputParser;
            p.addOptional('provider','Google',@ishcar);
            p.addOptional('clusterName','rtb4',@ischar);
            p.addOptional('zone','us-central1-a',@ischar);
            p.addOptional('instanceType','n1-highcpu-32',@ischar);
            p.addOptional('minInstances',1,@isnumeric);
            p.addOptional('maxInstances',10,@isnumeric);
            p.addOptional('preemptible',true,@islogical);
            p.addOptional('autoscaling',true,@islogical);
            p.addOptional('cloudBucket','',@ischar);
            p.addOptional('dockerImage','',@ischar);
            
            p.parse(varargin{:});
            
            obj.provider     = p.Results.provider;
            obj.clusterName  = p.Results.clusterName;
            obj.zone         = p.Results.zone;
            obj.instanceType = p.Results.instanceType;
            obj.minInstances = p.Results.minInstances;
            obj.maxInstances = p.Results.maxInstances;
            obj.preemptible  = p.Results.preemptible;
            obj.autoscaling  = p.Results.autoscaling;
            obj.cloudBucket  = p.Results.cloudBucket;
            obj.dockerImage  = p.Results.dockerImage;
            
            % Call the initialization function.
            obj.init();
            
            [~, obj.namespace] = system('echo -n $USER');
        end
        % List contents in a bucket.
        function [result, status, cmd] = ls(obj,bucketname)
            if ieNotDefined('bucketname')
                cmd = sprintf('gsutil ls');
                system(cmd);
            else
                d = bucketname;
                cmd = sprintf('gsutil ls %s\n',d);
                [status,result] = system(cmd);
            end
                
        end
        % Create a new bucket.
        function [result, status, cmd] = bucketCreate(obj,bucketname)
            if ieNotDefined('bucketname')
                disp('Bucket name must be given')
            else
                bname  = bucketname;
                cmd = sprintf('gsutil mb %s\n',bname);
                [status, result] = system(cmd);
            end
        end
        % Upload a folder or a file
        function [result, status, cmd] = upload(obj,local_dir,cloud_dir)
            %cloud_dir = fullfile(obj.bucket,cloud_dir);
            [~,~,ext] = fileparts(local_dir);
            if isempty(ext)
                cmd = sprintf('gsutil -m cp -r %s %s',local_dir,cloud_dir);
                [status, result] = system(cmd);
            else
                cmd = sprintf('gsutil cp %s %s',local_dir,cloud_dir);
                [status, result] = system(cmd);
            end
        end
        % Remove a bucket
        function [result, status, cmd]=rm(obj,name)
            cmd = sprintf('gsutil rm -r %s',name);
            [status, result] = system(cmd);
        end
        % Empty a bucket 
        function [result, status, cmd]=empty(obj,name)
            cmd = sprintf('gsutil rm  %s/**',name);
            [status, result] = system(cmd);
        end
        % Download a folder or a file
        function [result, status, cmd] = download(obj,cloud_dir,local_dir)
            cloud_dir = fullfile(obj.bucket,cloud_dir);
            cmd = sprintf('gsutil cp %s %s',cloud_dir,local_dir);
            [status, result] = system(cmd);
        end
%         % Push the docker rendering image to the project
%         function [result, status, cmd] = setDockerImage(obj,dockerAccount,dockerDir,dockerName)
%         % Check whether you have the necessary container. 
%         [containerDir, containerName] = fileparts(obj.dockerImage);
%         cmd = sprintf('gcloud container images list --repository=%s | grep %s',containerDir, containerName);
%         [status, result] = system(cmd);
%         if ieNotDefined('dockerAccount')
%             dAccount = 'hblasins';
%         else
%             dAccount = obj.dockerAccount;
%         end
%         % If you don't, it goes to work getting the container, tag it, and push it to
%         % the cloud.  This should really be on the RenderToolbox4 docker hub account in
%         % the future.
%         if isempty(result)
%             % We need to copy the container to gcloud 
%             cmd = sprintf('docker pull %s/%s',dAccount,containerName);
%             system(cmd);
%             cmd = sprintf('docker tag %s/%s %s/%s',dAccount,containerName, containerDir, containerName);
%             system(cmd);
%             cmd = sprintf('gcloud docker -- push %s/%s',containerDir, containerName);
%             system(cmd);
%         end
%         end
        % Display current configuration
        function [result, status, cmd] = Configlist(obj)
%             %list active account
%             cmd = sprintf('gcloud auth lists');
%             [status, result_auth]=system(cmd);
            %list clusters
            cmd = sprintf('gcloud container clusters list');
            [~, result_clusters]=system(cmd);
%             %list projects
%             cmd = sprintf('gcloud projects list');
%             [status, result_projects]=system(cmd);
            % list all properties in your active configuration
            cmd = sprintf('gcloud config list');
            [status, result_configuration]=system(cmd);
            result = sprintf('%s,%s\n',result_configuration,result_clusters);
            fprintf(result);
        end


    end
end