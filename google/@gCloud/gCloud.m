classdef gCloud < handle
% Interface from Matlab to Google Cloud Platform
%
% Syntax
%    gcp = gCloud(...)
%
% Description
%   This function sets up a k8s cluster on the google cloud platform.
%   The arguments set up various defaults (account, the docker image,
%   the storage bucket). 
%
% See also s_gCloud.m
%
% TODO
%   ZL thinks we should be able to swap the container that we call
%   easily by a separate call.  See note below.s
%
% HB/ZL/BW Vistasoft, 2017

% Example
%{
% Initialization example from s_gCloud

 dockerAccount= 'hblasins';
 dockerImage = 'gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud';
 cloudBucket = 'gs://primal-surfer-140120.appspot.com';
 gcp = gCloud('dockerAccount',dockerAccount,...
    'dockerImage',dockerImage,...
    'clusterName','happyRendering',...
    'cloudBucket',cloudBucket);
%}


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
        minInstances = 1;     %
        maxInstances = 10;    %
        preemptible  = true;  %
        autoscaling  = true;  %
        namespace    = '';    % 
        
        dockerImage  = '';
        dockerAccount= '';
        
        targets;    % What is this?
        
    end
    
    methods
       
        % Constructor and gcloud cluster initialization.
        function obj = gCloud(varargin)
            
            p = inputParser;
            
            % ieParamFormat goes here.  Force everything to lower
            % case and no spaces
            p.addParameter('provider','Google',@ischar);
            p.addParameter('clusterName','rtb4',@ischar);
            p.addParameter('zone','us-central1-a',@ischar);
            p.addParameter('instanceType','n1-highcpu-32',@ischar);
            p.addParameter('minInstances',1,@isnumeric);
            p.addParameter('maxInstances',10,@isnumeric);
            p.addParameter('preemptible',true,@islogical);
            p.addParameter('autoscaling',true,@islogical);
            p.addParameter('cloudBucket','',@ischar);
            p.addParameter('dockerImage','',@ischar);
            p.addParameter('dockerAccount','',@ischar);

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
            obj.dockerAccount  = p.Results.dockerAccount;

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
            % cloud_dir = fullfile(obj.bucket,cloud_dir);
            cmd = sprintf('gsutil cp %s %s',cloud_dir,local_dir);
            [status, result] = system(cmd);
        end
        
        % Display current configuration
        function [result, status, cmd] = Configlist(obj)
            cmd = sprintf('gcloud container clusters list');
            [~, result_clusters]=system(cmd);
            cmd = sprintf('gcloud config list');
            [status, result_configuration]=system(cmd);
            result = sprintf('%s,%s\n',result_configuration,result_clusters);
            fprintf(result);
        end
    end
end