function obj = init(obj, varargin )
% Initialize the gcloud and k8s cluster to run a docker image
%
% Syntax
%    gCloud.init(...)
%
% Description
%   Sets up the k8s cluster on the google cloud platform. This function is
%   called when you create the gCloud object.  It uses the defaults
%   (account, docker image, the storage bucket) that are set when you
%   create the gCloud instance.  It is not typically invoked on its own.
%
% Example
%   
%
% HB/ZL/BW Vistasoft, 2017


% TODO
%   ZL thinks we should be able to swap the container that we call
%   easily by a separate call.  See note below.

% Example
%{
%}

%% Check that we are in the right project

% Our lab has two projects
%
% * machine-driving-20180115, and
% * primal-surfer-140120
%
% We make sure we are in the right project before we run. This is both
% for billing and because the API might be set up differently between
% projects.

cmd = sprintf('gcloud config get-value project');
[~, result] = system(cmd);
result = result(1:end-1);
if ~strcmp(result, obj.projectid)
    cmd = sprintf('gcloud config set project %s',obj.projectid);
    system(cmd);
    cmd = sprintf('gcloud config get-value project');
    [~, result] = system(cmd);
end
fprintf('Project is set to %s\n',result);

%% List and possibly create the cluster

cmd = sprintf('gcloud container clusters list --filter=%s',obj.clusterName);
[status, result] = system(cmd);

% If the returned name is empty, create the cluster with this name
if ~piContains(result,obj.clusterName)
    
    cmd = sprintf('gcloud container clusters create %s --num-nodes=1 --max-nodes-per-pool=100 --machine-type=%s --zone=%s --scopes default,storage-rw',...
        obj.clusterName, obj.instanceType, obj.zone);
    
    if obj.preemptible
        cmd = sprintf('%s --preemptible',cmd);
    end
    
    if obj.autoscaling
        cmd = sprintf('%s --enable-autoscaling --min-nodes=%i --max-nodes=%i',...
            cmd, obj.minInstances, obj.maxInstances);
    end
    
    % Initiate creation
    tic; 
    fprintf('Creating a k8s cluster named %s ...',obj.clusterName)
    [status, result] = system(cmd);
    
    % Report back
    if status
        error('Problem creating cluster\n%s\n',result);
    else
        fprintf('Cluster %s created\n',obj.clusterName); 
    end
    
    % Report time.
    toc;
    
end

%% Get user credentials.

% The user credentials are stored by gcloud. The credentials define the
% container-cluster where the kubectl commands will be executed.
cmd = sprintf('gcloud container clusters get-credentials %s --zone=%s',...
    obj.clusterName,obj.zone);
system(cmd);

%% Cleanup

% The Container Cluster normally stores the completed jobs, and this
% uses resources (disk space, memory). We run a clean up service that
% periodically lists all succesfully completed jobs and removes them
% from the engine.

% Check if a namespace for a user exists, if it doesn't create one.
% gcp.namespaceExist;

cmd = sprintf('kubectl get namespaces | grep %s',obj.namespace);
[~, result] = system(cmd);
if isempty(result)
    cmd = sprintf('kubectl create namespace %s',obj.namespace);
    system(cmd);
end

%{
% Check for an existing cleanup job in the user namespace.
cmd = sprintf('kubectl get jobs --namespace=%s | grep cleanup',obj.namespace);
[~, result] = system(cmd);

% If not there, put one there
if isempty(strfind(result,'cleanup')) %#ok<STREMP>
    cmd = sprintf('kubectl run cleanup --limits cpu=100m --namespace=%s --restart=OnFailure --image=google/cloud-sdk -- /bin/bash -c ''while true; do echo "Starting"; kubectl delete jobs --namespace=%s $(kubectl get jobs --namespace=%s | awk ''"''"''$3=="1" {print $1}''"''"''); echo "Deleted jobs"; sleep 30; done''',...
        obj.namespace,obj.namespace,obj.namespace);
    system(cmd);
end
%}
%% Push the docker image to the project

% We probably want this as a separate command, like
% gCloud.setDockerImage(...)

% Parse the docker image
[containerDir, containerName] = fileparts(obj.dockerImage);

% Check whether the docker image is there
% dockerList = gcp.listDocker
cmd = sprintf('gcloud container images list --repository=%s | grep %s',containerDir, containerName);
[~, result] = system(cmd);

% If the image is not there get the container, tag it, and push it to
% the cloud.  The docker image for rendering should be on the
% RenderToolbox4 docker hub account in the future.  Right now it is
% where??? 
if isempty(result)
    % We need to copy the container to gcloud 
    cmd = sprintf('docker pull %s/%s',obj.dockerAccount,containerName);
    system(cmd);
    cmd = sprintf('docker tag %s/%s %s/%s',obj.dockerAccount,containerName, containerDir, containerName);
    system(cmd);
    cmd = sprintf('gcloud docker -- push %s/%s',containerDir, containerName);
    system(cmd);
end

end

