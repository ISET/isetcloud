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
                     'cloufdBucket',cloudBucket);
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
        maxInstances = 100;    %
        preemptible  = true;  %
        autoscaling  = true;  %
        namespace    = '';    %
        fwAPI;
        dockerImage  = '';
        dockerAccount= '';
        
        % Depth map flag
        renderDepth = false;
        % Mesh flag
        renderMesh  = false;
        % Render point cloud
        renderPointCloud = false;
        % Descriptor
        % TL: An extra property for misc descriptors that we want
        % to keep consistent with targets. I use it primarily to attach the
        % sceneEye object to the gCloud object so that each target will have
        % a corresponding sceneEye object. 
        miscDescriptor = [];
        bypass   = false;
        targets;    
        
    end
    
    
    methods
        
        % Constructor and gcloud cluster initialization.
        function obj = gCloud(varargin)
            
            p = inputParser;
            
            % Force lower case, no spaces
            varargin = ieParamFormat(varargin);
            
            % File is x.json
            p.addParameter('configuration','cloudRendering-pbrtv3-west1b-standard-32cpu-120m-flywheel',@(x)(exist([x,'.json'],'file')==2));
            
            p.addParameter('provider','Google',@ischar);
            p.addParameter('projectid','primal-surfer-140120',@ischar);
            p.addParameter('clustername','pbrtcloud',@ischar);
            p.addParameter('zone','us-west1-b',@ischar);
            p.addParameter('instancetype','n1-highcpu-32',@ischar);
            p.addParameter('mininstances',1,@isnumeric);
            p.addParameter('maxinstances',20,@isnumeric);
            p.addParameter('preemptible',true,@islogical);
            p.addParameter('autoscaling',true,@islogical);
            p.addParameter('cloudbucket','',@ischar);
            p.addParameter('dockerimage','',@ischar);
            p.addParameter('dockeraccount','',@ischar);
            p.addParameter('renderdepth',false,@islogical);
            p.addParameter('bypass',false,@islogical);
            
            p.parse(varargin{:});
            
            obj.provider     = p.Results.provider;
            obj.projectid    = p.Results.projectid;
            obj.clusterName  = p.Results.clustername;
            obj.zone         = p.Results.zone;
            obj.instanceType = p.Results.instancetype;
            obj.minInstances = p.Results.mininstances;
            obj.maxInstances = p.Results.maxinstances;
            obj.preemptible  = p.Results.preemptible;
            obj.autoscaling  = p.Results.autoscaling;
            obj.cloudBucket  = p.Results.cloudbucket;
            obj.dockerImage  = p.Results.dockerimage;
            obj.dockerAccount= p.Results.dockeraccount;
            obj.renderDepth  = p.Results.renderdepth;
            obj.bypass       = p.Results.bypass;
            
            [status, obj.namespace] = system('echo -n $USER');
            if status, error('Problem setting name space'); end
            
            if ~isempty(p.Results.configuration)
                % For default configurations, we read a json file that is
                % typically stored in the user's accounts directory.
                thisAccount = jsonread([p.Results.configuration,'.json']);
                
                obj.dockerAccount = thisAccount.dockerAccount;
                obj.projectid    = thisAccount.projectid;
                if isempty(p.Results.dockerimage)
                    obj.dockerImage  = thisAccount.dockerImage;
                end
                obj.clusterName  = [thisAccount.clusterName,'-',obj.namespace];
                obj.cloudBucket  = thisAccount.cloudBucket;
                obj.zone         = thisAccount.zone;
                obj.instanceType = thisAccount.instanceType;
            end
            
            % Go for it
            if ~obj.bypass
                obj.init();
            end
        end
        
        function [result, status, cmd]=clusterDelete(obj)
            % Shut down and delete a k8s cluster
            %
            % ZL
            %
            % See also
            
            fprintf('Removing the cluster %s\n',obj.clusterName);
            if notDefined('zone')
                cmd = sprintf('gcloud container clusters delete %s --zone=%s',obj.clusterName,obj.zone);
            else
                cmd = sprintf('gcloud container clusters delete %s --zone=%s',obj.clusterName,obj.zone);
            end
            
            fprintf('Initiated cluster deletion.  This can take 3-5 minutes.\n');
            [status, result] = system(cmd);
            if status
                error('Cluster delete failure\n %s\n',result);
            end
        end
        
        function [result, status, cmd] = ls(obj,varargin)
            % List the contents of a bucket on the cloud
            %
            % print:  logical, for printing out the listing to the command
            %         line
            % folder: a specific bucket within the root cloudBucket
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
            if ~isempty(folder), d = fullfile(d, obj.namespace, folder); end
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
        
        function [result, status, cmd] = bucketCreate(~,bucketname)
            % Create a bucket with a specific name
            if notDefined('bucketname')
                disp('Bucket name required')
            else
                bname  = bucketname;
                cmd = sprintf('gsutil mb %s\n',bname);
                [status, result] = system(cmd);
            end
        end
        
        function [result, status, cmd] = upload(~,local_dir,cloud_dir)
            % Upload a folder or a file to a directory in the cloud
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
        
        function [result, status, cmd] = rm(~,name)
            % Remove an entire bucket
            cmd = sprintf('gsutil rm -r %s',name);
            [status, result] = system(cmd);
        end
        
        function [result, status, cmd]=emptyBucket(~,name)
            % Empty the files inside a bucket
            cmd = sprintf('gsutil rm  %s/**',name);
            [status, result] = system(cmd);
        end
        
        % Download a folder or a file
        function [result, status, cmd] = download(~,cloud_dir,local_dir)
            % cloud_dir = fullfile(obj.bucket,cloud_dir);
            cmd = sprintf('gsutil cp %s %s',cloud_dir,local_dir);
            [status, result] = system(cmd);
        end
        
        function [result, status, cmd] = configList(obj,varargin)
            % Display configuration for current cluster and account
            p = inputParser;
            p.addRequired('obj',@(x)(isa(x,'gCloud')));
            p.addParameter('name',obj.clusterName,@ischar);
            p.parse(obj,varargin{:});
            name = p.Results.name;
            
            % Get information about the clusters from the gcloud container
            cmd = sprintf('gcloud container clusters list --format=json');
            [~, result_clusters_old] = system(cmd);
            result_clusters_old = jsondecode(result_clusters_old);
            
            %{
             %We only preserve some fields.  These we delete.
            
             fields = {'addonsConfig','clusterIpv4Cidr','currentMasterVersion',...
                       'currentNodeCount', 'currentNodeVersion','endpoint','initialClusterVersion','instanceGroupUrls',...
                       'labelFingerprint','legacyAbac','loggingService','monitoringService','network',...
                       'ipAllocationPolicy','nodePools','selfLink','servicesIpv4Cidr','masterAuth',...
                       'nodeConfig','locations','subnetwork','networkConfig','location','defaultMaxPodsConstraint'};
            %}
            fields = {'name', 'zone', 'status','createTime'}; %,};
            for ii = 1:length(fields)
                result_clusters.(fields{ii}) = result_clusters_old.(fields{ii});
            end
            % result_clusters = orderfields(result_clusters, ...
            %    {'name', 'zone', 'status','createTime','currentNodeCount'});
            
            % We only want the cluster associated with this GCP name
            idx = strcmp(name,{result_clusters(:).name});
            result_clusters = result_clusters(idx);
            
            % Now get the configuration of the cluster
            cmd = sprintf('gcloud config list --format=json');
            [status, result_configuration] = system(cmd);
            result_configuration=jsondecode(result_configuration);
            
            % result_clusters = struct2table(result_clusters);
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
        
        function targetsList(obj)
            % Display a nice list of the targets
            if isempty(obj.targets)
                fprintf('No targets\n');
            else
                fprintf('\nCamera\t\t local\t\t remote\t\t metadata\n')
                fprintf('--------------------------------------------------------\n');
                for ii =1:length(obj.targets)
                    cType = obj.targets(ii).camera.subtype;
                    [~,localFile,e1] = fileparts(obj.targets(ii).local);
                    [~,remoteFile,e2] = fileparts(obj.targets(ii).remote);
                    dFlag = obj.targets(ii).depthFlag;
                    fprintf('%d: %s\t%s\t%s\t%d\n',ii,cType,[localFile,e1],[remoteFile,e2],dFlag);
                    
                end
            end
        end
        
        %% kubectl related methods
        
        function [jobNames] = jobsList(obj,varargin)
            % List the running jobs in a specific name space or in all
            % name spaces.
            % 
            % Optional key/value
            %  'name space' - User name space to check
            %
            % obj.jobsList('name space','wandell')
            %
            % See also
            %   obj.jobsDelete
            
            %%
            p = inputParser;
            varargin = ieParamFormat(varargin);
            
            p.addParameter('namespace',obj.namespace,@ischar);
            p.addParameter('print',true,@islogical);
            
            p.parse(varargin{:});
            
            thisNameSpace = p.Results.namespace;
            
            %% Run kubectl
            if strcmp(thisNameSpace,'all')
                cmd = sprintf('kubectl get jobs --all-namespaces -o json');
            else
                cmd = sprintf('kubectl get jobs --namespace=%s -o json',thisNameSpace);
            end
            
            [status,result] = system(cmd);  
            jobNames = [];
            if status
                error('Name space read error\n%s\n',result);
            else
                result = jsondecode(result);
                if p.Results.print
                    % This is a printable listing.  I guess we could
                    % build it ourselves from results
                    succeeded = [];
                    fprintf('\n----Active-------\n');
                    fprintf(['ITEM','NAME',repmat(' ',1,40),'STATUS    START',repmat(' ',1,10),'AGE','\n']');
                    for ii=1:length(result.items)
                        try
                            if result.items(ii).status.succeeded
                                succeeded = [succeeded,ii];
                            end
                        catch
                            fprintf('%d ',ii);
                            fprintf('%s ',result.items(ii).metadata.name);
                            fprintf('\t%d ',result.items(ii).status.active);
                            pat = '(?<year>\d+)-(?<month>\d+)-(?<day>\d+)T(?<hour>\d+):(?<min>\d+):(?<sec>\d+)';
                            startTime = regexp(result.items(ii).status.startTime,pat,'names');
                            startTime.hour = str2double(startTime.hour)-7; % set for different timezone
                            if startTime.hour<0, startTime.hour = startTime.hour+24;end
                            currentTime = clock;
                            if (currentTime(4)-startTime.hour)==0
                                age = currentTime(5)-str2double(startTime.min);
                            else
                                age = (currentTime(4)-startTime.hour)*60 - str2double(startTime.min) + currentTime(5);
                            end
                            fprintf('\t%d:%d:%d ', startTime.hour, str2double(startTime.min), str2double(startTime.sec));
                            fprintf('\t%d mins ', age);
                            jobNames = [jobNames,' ',result.items(ii).metadata.name];
                        end
                    end
                    fprintf('\n\n----Succeeded------\n');
                    
                    for ii=1:length(succeeded)
                        thisJob = succeeded(ii);
                        pat = '(?<year>\d+)-(?<month>\d+)-(?<day>\d+)T(?<hour>\d+):(?<min>\d+):(?<sec>\d+)';
                        startTime = regexp(result.items(thisJob).status.startTime, pat,'names');
                        startTime.hour = str2double(startTime.hour)-7;
                        fprintf('%d %s. Started at %d:%d:%d \n',...
                        thisJob,result.items(thisJob).metadata.name,...
                            startTime.hour, str2double(startTime.min), str2double(startTime.sec));
                        jobNames = [jobNames,' ',result.items(thisJob).metadata.name];
                    end
                    fprintf('\n\n');
                else
                    for ii=1:length(result.items)
                        jobNames = [jobNames,' ',result.items(ii).metadata.name];
                    end
                end
            end
                        
        end
        
        function [nSucceeded,jobs] = jobsStatus(obj, varargin)
            % Report on the status of the kubernetes jobs
            %
            % Syntax
            %   [nSucceeded,jobs] = obj.jobsStatus
            %
            % Key/value options
            %   'print'  - Printout a summary if true
            %
            % Returns
            %   nSucceeded - number of jobs with status succeeded
            %   jobs  - the struct of all the jobs returned by kubectl
            %
            % The code might be used like this
            %
            %  cnt = 0;
            %  while cnt < length(gcp.targets)
            %    cnt = obj.jobsStatus;
            %    pause(5);
            %  end
            %
            % ZL/BW, Vistasoft team, 2018
            %
            % See also
            %
            
            %%
            p = inputParser;
            varargin = ieParamFormat(varargin);
            p.addParameter('namespace',obj.namespace,@ischar);
            p.addParameter('print',true,@islogical);
            
            p.parse(varargin{:});
            
            thisNameSpace = p.Results.namespace;
            
            %% Run kubectl
            cmd = sprintf('kubectl get jobs --namespace=%s -o json',thisNameSpace);
            [status,result] = system(cmd);
            if status
                error('Name space read error\n%s\n',result);
            else
                jobs = jsondecode(result);
            end
            nJobs = length(jobs.items);

            % Calculate the number that were successful
            nSucceeded = 0;
            for ii=1:nJobs
                % Sometimes we get stray jobs here that have not been
                % started. They have no slot for succeeded.
                if isfield(jobs.items(ii).status,'succeeded')
                    if jobs.items(ii).status.succeeded == 1
                        nSucceeded = nSucceeded + 1;
                    end
                end
            end

            % Tell the user
            if p.Results.print
                fprintf('Found %d jobs. N Succeeded = %d\n',nJobs,nSucceeded);
                fprintf('------------\n');
            end
        end
        
        function [result, status, cmd] = jobsDelete(obj)
            % Deletes all of the running jobs
            %
            
            % Might want to turn off printout
            cmd = sprintf('kubectl delete jobs --all --namespace=%s',obj.namespace);
            
            fprintf('Deleting all jobs in name space %s\n',obj.namespace)
            [status, result] = system(cmd);
            if status, warning('Jobs not correctly deleted\n'); end
            fprintf('%s\n',result);
        end
        
        function [result,status,cmd] = namespaceList(~,varargin)
            % List all the name spaces currently on the cluster
            cmd = sprintf('kubectl get namespaces');
            [status,result] = system(cmd);
            if status
                error('Name space read error\n%s\n',result);
            end
        end
        
        function [pod,result,status,cmd] = podsList(obj, varargin)
            % List the status of the kubernetes pods, the smallest
            % deployable instance of a running process in the cluster. 
            % 
            % PODS typically run in a Node.  Often there is one POD
            % per node, if the resources to run the POD is matched to
            % what is available on a single node.
            %
            % If you think the status should be initialized and no
            % PODS are running, then the return would be 'No resources
            % found'.
            
            %% Read input parameters
            p = inputParser;
            p.addRequired('obj',@(x)(isa(x,'gCloud')));
            p.addParameter('print',true,@islogical);
            p.parse(obj,varargin{:});
            
            % Invoke kubernetes
            cmd = sprintf('kubectl get pods --namespace=%s -o json',obj.namespace);
            [status, result_original] = system(cmd);
            if status, warning('Did not read pods correctly'); end
            
            % Decode the json return data
            try
                result = jsondecode(result_original);
                if ~isempty(result.items)
                    pod = cell(length(result.items),1);
                    for ii=1:length(result.items)
                        podname= result.items(ii).metadata.name;
                        if p.Results.print
                            fprintf('%s is %s \n', podname, result.items(ii).status.phase);
                        end
                        pod{ii}=podname;
                    end
                end
            catch
                warning('jsondecode error. result_original\n %s',result_original);
                fprintf('No resources found.  Returning empty pod.\n');
                pod = [];
            end            
        end
        
        function [result,status,cmd] = PodDescribe(obj,podname)
            cmd = sprintf('kubectl describe pod %s --namespace=%s',podname,obj.namespace);
            [status, result] = system(cmd);
        end
        
        function cmd = Podlog(obj,podname)
            % The returned cmd can be copied into the terminal and you will
            % learn about the activity of the POD with this name.  
            % POD is the process
            cmd = sprintf('kubectl logs -f --namespace=%s %s',obj.namespace,podname);
            fprintf('Copy this into the terminal to see the log:\n%s\n',cmd);
        end
            
    end
end