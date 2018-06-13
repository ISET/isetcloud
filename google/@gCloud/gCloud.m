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
    %   easily by a separate call.  See note below.
    %
    % HB/ZL/BW Vistasoft, 2017
    
    % Example
    %{
      % Initialization example from s_gCloud

        dockerAccount = 'hblasins';
        dockerImage   = 'gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud';
        cloudBucket   = 'gs://primal-surfer-140120.appspot.com';
        gcp = gCloud('dockerAccount',dockerAccount,...
                     'dockerImage',dockerImage,...
                     'clusterName','happyrendering',...
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
        projectid    = 'primal-surfer-140120';
        clusterName  = 'pbrtrender';
        zone         = 'us-central1-a';
        instanceType = 'n1-highcpu-32';
        minInstances = 1;     %
        maxInstances = 10;    %
        preemptible  = true;  %
        autoscaling  = true;  %
        namespace    = '';    %
        
        dockerImage  = '';
        dockerAccount= '';
        
        % Depth map flag
        renderDepth = false;
        
        % Descriptor
        % TL: An extra property for misc descriptors that we want
        % to keep consistent with targets. I use it primarily to attach the
        % sceneEye object to the gCloud object so that each target will have
        % a corresponding sceneEye object. 
        miscDescriptor = [];
        
        targets;    
        
    end
    
    
    methods
        
        % Constructor and gcloud cluster initialization.
        function obj = gCloud(varargin)
            
            p = inputParser;
            
            % ieParamFormat goes here.  Force everything to lower
            % case and no spaces
            p.addParameter('provider','Google',@ischar);
            p.addParameter('projectid','primal-surfer-140120',@ischar);
            p.addParameter('clusterName','pbrtcloud',@ischar);
            p.addParameter('zone','us-central1-a',@ischar);
            p.addParameter('instanceType','n1-highcpu-32',@ischar);
            p.addParameter('minInstances',1,@isnumeric);
            p.addParameter('maxInstances',10,@isnumeric);
            p.addParameter('preemptible',true,@islogical);
            p.addParameter('autoscaling',true,@islogical);
            p.addParameter('cloudBucket','',@ischar);
            p.addParameter('dockerImage','',@ischar);
            p.addParameter('dockerAccount','',@ischar);
            p.addParameter('renderDepth',false,@islogical);
            
            p.parse(varargin{:});
            
            obj.provider     = p.Results.provider;
            obj.projectid    = p.Results.projectid;
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
            obj.renderDepth = p.Results.renderDepth;
            
            [status, obj.namespace] = system('echo -n $USER');

            % Call the initialization function.
            obj.init();
            
            if status, error('Problem setting name space'); end
            
        end
        
        % Shut down and remove a k8s cluster
        function [result, status, cmd]=clusterRm(obj)
            fprintf('Removing the cluster %s\n',obj.clusterName);
            fprintf('This can take a 3 or even 5 of minutes\n');
            if notDefined('zone')
                cmd = sprintf('gcloud container clusters delete %s --zone=%s',obj.clusterName,obj.zone);
            else
                cmd = sprintf('gcloud container clusters delete %s --zone=%s',obj.clusterName,obj.zone);
            end
            [status,result]= system(cmd);
        end
        
        % List contents in a bucket.
        function [result, status, cmd] = ls(obj,varargin)
            % print:  logical, for printing out the listing to the command
            %         line
            % folder: a specific budget within the general cloudBucket
            %
            % gCloud.ls('folder','wandell');
            % gCloud.ls('folder','wandell/stop');
            
            p = inputParser;
            p.addParameter('print',false,@logical);
            p.addParameter('folder','',@ischar);
            
            p.parse(varargin{:});
            print  = p.Results.print;
            folder = p.Results.folder;

            d = obj.cloudBucket;
            if ~isempty(folder), d = fullfile(d,folder); end
            cmd = sprintf('gsutil ls %s\n',d);
            [status,result] = system(cmd);
            
            if ~isempty(result)
                % Converts the char array return to a cell array
                files = split(result);
                ispresent = cellfun(@(s) ~isempty(s), files);
                result = files(ispresent);
                if print
                    fprintf('\n----------------------\n');
                    for ii=1:length(result)
                        fprintf('%d:  %s\n',ii,result{ii});
                    end
                end
            else
                if print
                    disp('Print empty result here.  Not yet implemented')
                end
            end            
        end
        
        % List the buckets
        function [result, status, cmd] = bucketList(obj)
            disp('bucketList not yet implemented');
        end
        
        
        % Create a new bucket.
        function [result, status, cmd] = bucketCreate(obj,bucketname)
            if notDefined('bucketname')
                disp('Bucket name must be given')
            else
                bname  = bucketname;
                cmd = sprintf('gsutil mb %s\n',bname);
                [status, result] = system(cmd);
            end
        end
        
        % Upload a folder or a file to a directory in the cloud
        function [result, status, cmd] = upload(obj,local_dir,cloud_dir)
            % cloud_dir = fullfile(obj.bucket,cloud_dir);
            %
            [~,~,ext] = fileparts(local_dir);
            if isempty(ext)
                cmd = sprintf('gsutil -m cp -r %s %s',local_dir,cloud_dir);
                [status, result] = system(cmd);
            else
                cmd = sprintf('gsutil cp %s %s',local_dir,cloud_dir);
                [status, result] = system(cmd);
            end
        end
        
        % Remove the entire bucket
        function [result, status, cmd] = rm(obj,name)
            cmd = sprintf('gsutil rm -r %s',name);
            [status, result] = system(cmd);
        end
        
        % Empty the files inside a bucket
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
            % List the cluster information from the gcloud container
            cmd = sprintf('gcloud container clusters list --format=json');
            [~, result_clusters]=system(cmd);
            result_clusters=jsondecode(result_clusters);
            fields = {'addonsConfig','clusterIpv4Cidr','currentMasterVersion',...
                'currentNodeVersion','endpoint','initialClusterVersion','instanceGroupUrls',...
                'labelFingerprint','legacyAbac','loggingService','monitoringService','network',...
                'nodeIpv4CidrSize','nodePools','selfLink','servicesIpv4Cidr','masterAuth','nodeConfig','locations','subnetwork'};
            result_clusters = rmfield(result_clusters,fields);
            result_clusters = orderfields(result_clusters, {'name', 'zone', 'status','createTime','currentNodeCount'});
            
            cmd = sprintf('gcloud config list --format=json');
            [status, result_configuration]=system(cmd);
            result_configuration=jsondecode(result_configuration);
            
%           result_clusters = struct2table(result_clusters);
            result_configuration = result_configuration.core;
            if isfield(result_configuration,'disable_usage_reporting')
                result_configuration = rmfield(result_configuration,'disable_usage_reporting');
            end
            
            % Display (always?)
             disp('*************Project Information*************');
            disp(result_configuration);
            disp('*************Cluster Information*************');
            disp(result_clusters);
            
            % Configure result
            result.configuration = result_configuration;
            result.clusters = result_clusters;
            
        end
        
        %% kubectl related methods
        
        % List the jobs in a specific name space or in all name spaces
        function [result,status,cmd] = listJobs(obj,varargin)
            % List all the jobs in all the name spaces
            % Or we will parse the varargin and find one particular
            % name space
            p = inputParser;
            varargin = ieParamFormat(varargin);
            p.addParameter('namespace',obj.namespace,@ischar);
            p.parse(varargin{:});
            thisNameSpace = p.Results.namespace;
            
            if strcmp(thisNameSpace,'all')
                cmd = sprintf('kubectl get jobs --all-namespaces');
            else
                cmd = sprintf('kubectl get jobs --namespace=%s',thisNameSpace);
            end
            
            [status,result] = system(cmd);
            if status
                error('Name space read error\n%s\n',result);
            end
        end
        function [result, status, cmd] = checkJobs(obj, varargin)
            p = inputParser;
            varargin = ieParamFormat(varargin);
            p.addParameter('namespace',obj.namespace,@ischar);
            p.parse(varargin{:});
            thisNameSpace = p.Results.namespace;
            cmd = sprintf('kubectl get jobs --namespace=%s -o json',thisNameSpace);
            [status,result] = system(cmd);
            if status
                error('Name space read error\n%s\n',result);
            end
            result = jsondecode(result);
            NumofJobs = sum(~cellfun(@isempty,{result.items}));
            NumofJobs = NumofJobs - 1;
            fprintf('%d job to be done \n', NumofJobs);
        end
        
        % List all the name spaces currently on the cluster
        function [result,status,cmd] = listNames(obj,varargin)
            cmd = sprintf('kubectl get namespaces');
            [status,result] = system(cmd);
            if status
                error('Name space read error\n%s\n',result);
            end
        end
        
        function [result,status,cmd,pod] = Podslist(obj)
                cmd = sprintf('kubectl get pods --namespace=%s -o json',obj.namespace);
                [status, result_original] = system(cmd);
                
                result = jsondecode(result_original);
                if ~isempty(result.items)
                for i=1:length(result.items)
                podname= result.items(i).metadata.name;
                fprintf('%s is %s \n', podname, result.items(i).status.phase)
                pod{i}=podname;
                end
                else
                    fprintf('No resources found\n')
                
                end
                if status
                    warning('Did not read pds correctly');
                end
        end
        function [result,status,cmd] = PodDescribe(obj,podname)
            cmd = sprintf('kubectl describe pod %s --namespace=%s',podname,obj.namespace);
            [status, result] = system(cmd);
        end
        function [result, status,cmd] = Podlog(obj,podname)
                cmd = sprintf('kubectl logs -f --namespace=%s %s',obj.namespace,podname);
                [status, result] = system(cmd);
                if status, warning('Log not returned correctly\n'); end
                fprintf('%s\n',result);
        end
        function [result, status, cmd] = JobsRmAll(obj)
            cmd = sprintf('kubectl delete jobs --all --namespace=%s',obj.namespace);
                [status, result] = system(cmd);
            if status, warning('Jobs are not correctly deleted\n'); end
            fprintf('%s\n',result);
        end
            
    end
end