function [ obj ] = render( obj )
% Invoke PBRT docker image on the kubernetes cluster
%
% Syntax
%   gcp.render;
%
% Description
%   The targets slot contains the specific jobs that we want to start
%   up on the cluster.  The other slots include the information about
%   the cluster.
%
% See also:  s_mcRender
%
% ZL

nTargets = length(obj.targets);
fprintf('Starting %d jobs\n',nTargets);

for t=1:length(obj.targets)
    
%     jobName = lower(obj.targets(t).remote);
%     jobName(jobName == '_' | jobName == '.' | jobName == '-' | jobName == '/' | jobName == ':') = '';
%     jobName = jobName(max(1,length(jobName)-62):end);
    [~,jobName] = fileparts(obj.targets(t).local);
    jobName(jobName == '_' | jobName == '.' | jobName == '-' | jobName == '/' | jobName == ':') = '';
    jobName=lower(jobName);
    jobName = jobName(max(1,length(jobName)-62):end);
    % Kubernetes does not allow two jobs with the same name.
    % We delete any jobs with the current name.
    kubeCmd = sprintf('kubectl delete job --namespace=%s %s',obj.namespace,jobName);
    [status, result] = system(kubeCmd);
    %     if status
    %         warning('No job named %s in the name space\n%s',jobName,result);
    %     end

    % This is the number of permissible cores
    % Find the first position with a dash
    loc = strfind(obj.instanceType,'-');
    nCores = str2double(obj.instanceType(loc(2)+1:end));
     
    % Run the shell script cloudRenderPBRT2ISET.sh on the cluster
    % The parameters to the shell script are 
%     kubeCmd = sprintf('kubectl run %s --image=%s --namespace=%s --restart=OnFailure --limits cpu=%im  -- ./cloudRenderPBRT2ISET.sh  "%s" ',...
%         jobName,...
%         obj.dockerImage,...
%         obj.namespace,...
%         (nCores-0.9)*1000,...
%         obj.targets(t).remote);
    % From flyweehl to kubernetes
        kubeCmd = sprintf('kubectl run %s --image=%s --namespace=%s --restart=OnFailure --limits cpu=%im  -- ../code/fwrender.sh  "%s" "%s" "%s" "%s" ',...
        jobName,...
        obj.dockerImage,...
        obj.namespace,...
        (nCores-0.9)*1000,...
        obj.targets(t).fwAPI.key,...
        obj.targets(t).fwAPI.sceneFilesID.acquisition,...
        obj.targets(t).fwAPI.InfoList,...
        obj.targets(t).fwAPI.projectID);

    
    [status, result] = system(kubeCmd);
    % disp the pods running under the namespace
    if status
        warning('Job did not start correctly');
    end
    % Or maybe it did start and we print this anyway
    fprintf('%s\n',result);
    
end

end


%% Learn about who is active.  The result is a json file
% We might move this checking type function out into another
% routine that monitors how we are doing.

%     cmd = sprintf('kubectl get pods -o json --namespace=%s',obj.namespace);
%     [status, result] = system(cmd);
%     if status
%         warning('Did not read pds correctly');
%     end
%
%     % Kubernetes uses pod to be a group of 'containers'.  I am not
%     % sure what containers are, maybe 'workers' or processes or
%     % something. (BW).
%     result = jsondecode(result);
%     cmd    = sprintf('kubectl logs -f --namespace=%s %s',obj.namespace,result.items(end).metadata.name);
%     [status, result] = system(cmd);
%     if status, warning('Log not returned correctly\n'); end
%     fprintf('%s\n',result);

