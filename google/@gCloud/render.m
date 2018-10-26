function [ obj ] = render( obj )
% Invoke PBRT docker image on the kubernetes cluster
%
% Syntax
%   gcp.render;
%
% Description
%   The obj contains a slot, targets, that lists the specific jobs
%   that we want to start up on the cluster.  This render method
%   starts a job for each of the targets.
%
% ZL, Vistasoft Team, 2018
%
% See also:  
%   s_mcRender
%

%% Each rendering job is called a target
nTargets = length(obj.targets);
fprintf('Starting %d jobs\n',nTargets);

for t=1:length(obj.targets)
    
    jobName = lower(obj.targets(t).remote);
    jobName(jobName == '_' | jobName == '.' | jobName == '-' | jobName == '/' | jobName == ':') = '';
    jobName = jobName(max(1,length(jobName)-62):end);
    
    % Kubernetes does not allow two jobs with the same name.
    % We delete any jobs with the current name.
    kubeCmd = sprintf('kubectl delete job --namespace=%s %s',obj.namespace,jobName);
    [status, result] = system(kubeCmd);
    if status
        if contains(result,'NotFound')
            % Ignore the status.  We tried to delete something that
            % did not exist.
        else
            % It exists.
            warning('Problem deleting job %s.\nResult: %s\n',jobName,result);
        end
    end

    % This is the number of permissible cores
    % Find the first position with a dash
    loc = strfind(obj.instanceType,'-');
    nCores = str2double(obj.instanceType(loc(2)+1:end));
     
    % Run the shell script cloudRenderPBRT2ISET.sh on the cluster
    % The parameters to the shell script are 
    kubeCmd = sprintf('kubectl run %s --image=%s --namespace=%s --restart=OnFailure --limits cpu=%im  -- ./cloudRenderPBRT2ISET.sh  "%s" ',...
        jobName,...
        obj.dockerImage,...
        obj.namespace,...
        (nCores-0.9)*1000,...
        obj.targets(t).remote);
    
    % Start the job an announce result
    [status, result] = system(kubeCmd);
    if status
        warning('Problem starting job %s (name space %s)\n',jobName,obj.namespace);
    else    
        fprintf('Started %s\n', result);
    end
    
end

end

