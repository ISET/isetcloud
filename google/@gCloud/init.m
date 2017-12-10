function obj = init(obj, varargin )
% Initialize the gcloud container and k8s cluster to run a docker
% image
%
% Syntax
%    gCloud.init(...)
%
% Description
%   This function sets up the k8s cluster on the google cloud
%   platform. It uses the defaults (account, the docker image, the
%   storage bucket) that are set when you first create the gCloud
%   instance.  This function is called when you create the gCloud
%   object.  It is not typically invoked on its own.
%
% Example
%   
% TODO
%   ZL thinks we should be able to swap the container that we call
%   easily by a separate call.  See note below.
%
% HB/ZL/BW Vistasoft, 2017

% Example
%{
%}


%% List the containers. 
cmd = sprintf('gcloud container clusters list --filter=%s',obj.clusterName);
[~, result] = system(cmd);

% If they aren't there, create them
if isempty(result)
    
    cmd = sprintf('gcloud container clusters create %s --num-nodes=1 --max-nodes-per-pool=100 --machine-type=%s --zone=%s --scopes default,storage-rw',...
        obj.clusterName, obj.instanceType, obj.zone);
    
    if obj.preemptible
        cmd = sprintf('%s --preemptible',cmd);
    end
    
    if obj.autoscaling
        cmd = sprintf('%s --enable-autoscaling --min-nodes=%i --max-nodes=%i',...
            cmd, obj.minInstances, obj.maxInstances);
    end
    
    tic; fprintf('Calling gcloud to create the k8s cluster %s ...',obj.clusterName)
    [~, result] = system(cmd);
    fprintf('done\n'); toc;
    
    % Returned result
    fprintf('%s\n',result);
end

%% Once the container cluster is created get your user credentials.

% This defines the container-cluster where your kubectl commands will be
% executed.
cmd = sprintf('gcloud container clusters get-credentials %s --zone=%s',...
    obj.clusterName,obj.zone);
system(cmd);

%% Cleanup

% The Container Cluster stores the completed jobs, and they use up
% resources (disk space, memory). We run a simple service that
% periodically lists all succesfully completed jobs and removes them
% from the engine.

% Check if a namespace for a user exists, if it doesn't create one.
cmd = sprintf('kubectl get namespaces | grep %s',obj.namespace);
[~, result] = system(cmd);
if isempty(result)
    cmd = sprintf('kubectl create namespace %s',obj.namespace);
    system(cmd);
end

% This is how you run the clean up
% Create a cleanup job in the user namespace.
cmd = sprintf('kubectl get jobs --namespace=%s | grep cleanup',obj.namespace);
[~, result] = system(cmd);

if isempty(strfind(result,'cleanup')) %#ok<STREMP>
    cmd = sprintf('kubectl run cleanup --limits cpu=100m --namespace=%s --restart=OnFailure --image=google/cloud-sdk -- /bin/bash -c ''while true; do echo "Starting"; kubectl delete jobs --namespace=%s $(kubectl get jobs --namespace=%s | awk ''"''"''$3=="1" {print $1}''"''"''); echo "Deleted jobs"; sleep 30; done''',...
        obj.namespace,obj.namespace,obj.namespace);
    system(cmd);
end

%% To change:  Push the docker rendering image to the project
% 
% We probably want this as a separate command, like
% gCloud.setDockerImage(...)
[containerDir, containerName] = fileparts(obj.dockerImage);

% Check whether you have the necessary container
cmd = sprintf('gcloud container images list --repository=%s | grep %s',containerDir, containerName);
[~, result] = system(cmd);

% If you don't, it goes to work getting the container, tag it, and push it to
% the cloud.  This should really be on the RenderToolbox4 docker hub account in
% the future.
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

