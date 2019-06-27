function [ obj ] = render( obj, varargin )
% Render an ISET3d scene by invoking PBRT docker image on a k8s cluster
%
% Syntax
%   gcp.render();
%
% Description
%   The obj is a gCloud object that contains the targets and jobs that we
%   want to start up on the cluster.  This render method starts a job for
%   each of the targets.
%
% ZL, Vistasoft Team, 2018
%
% See also:  
%

%%
p = inputParser;
p.addParameter('replaceJob',false,@isnumeric);
p.parse(varargin{:});
replaceJob = p.Results.replaceJob;
%% Each rendering job is called a target
nTargets = length(obj.targets);
fprintf('Starting %d jobs\n',nTargets);

for t=1:nTargets
    [~,jobName] = fileparts(obj.targets(t).local);
    jobName(jobName == '_' | jobName == '.' | jobName == '-' | jobName == '/' | jobName == ':') = '';
    jobName=lower(jobName);
    jobName = jobName(max(1,length(jobName)-62):end);
    % Kubernetes does not allow two jobs with the same name.
    % We delete any jobs with the current name.
    if replaceJob
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
    else
        jobsNamesAll = obj.jobsList('print',false);
        if piContains(jobsNamesAll, jobName)            
            fprintf('Job %s is exist. \n', jobName);
            continue
        end
    end

    % This is the number of permissible cores
    % Find the first position with a dash
    if piContains(obj.instanceType, 'n1')
        loc = strfind(obj.instanceType,'-');
        nCores = str2double(obj.instanceType(loc(2)+1:end));
    elseif piContains(obj.instanceType, 'custom')
        loc = strfind(obj.instanceType,'-');
        nCores = str2double(obj.instanceType(loc(1)+1:loc(1)+2));
    end
    
    % The kubectl command invokes a script (fwrender.m) that copies all the
    % render resources from flywheel to the kubernetes instance we
    % initiated.  It then invokes the PBRT docker image.
    %
    % We use all the allocated cores.  The 1000 scale factor is how the GCP
    % people describe the units of the CPU.
    if isfield(obj.targets(t), 'fwAPI')
        kubeCmd = sprintf('kubectl run %s --image=%s --namespace=%s --restart=OnFailure --limits cpu=%im  -- ../code/fwrender.sh  "%s" "%s" "%s" "%s" ',...
            jobName,...
            obj.dockerImage,...
            obj.namespace,...
            (nCores-0.9)*1000,...
            obj.targets(t).fwAPI.key,...
            obj.targets(t).fwAPI.sceneFilesID,...
            obj.targets(t).fwAPI.InfoList,...
            obj.targets(t).fwAPI.projectID);
    else
        kubeCmd = sprintf('kubectl run %s --image=%s --namespace=%s --restart=OnFailure --limits cpu=%im  -- ./cloudRenderPBRT2ISET.sh  "%s" ',...
            jobName,...
            obj.dockerImage,...
            obj.namespace,...
            (nCores-0.9)*1000,...
            obj.targets(t).remote);
    end
    % Start the rendering job and announce that the job is started (or not)
    [status, result] = system(kubeCmd);
    if status
        warning('Problem starting job %s (name space %s)\n',jobName,obj.namespace);
    else
        fprintf('Started %s\n', result);
    end
    
end

end

%% NOTES     

% We used to run the shell script cloudRenderPBRT2ISET.sh on the cluster
% The parameters to the shell script are
%     kubeCmd = sprintf('kubectl run %s --image=%s --namespace=%s --restart=OnFailure --limits cpu=%im  -- ./cloudRenderPBRT2ISET.sh  "%s" ',...
%         jobName,...
%         obj.dockerImage,...
%         obj.namespace,...
%         (nCores-0.9)*1000,...
%         obj.targets(t).remote);
