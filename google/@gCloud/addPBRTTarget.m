function target = addPBRTTarget(obj, thisR,varargin)
% Add a PBRT target job to the google cloud engine instance
%
%   NOTE:  This should be named targetAdd
%
% Syntax
%    target = addPBRTTarget(obj,thisR,varargin);
%
% Description
%  We modify the gcp object to contain a list of rendering targets for
%  the gcloud.render option.
%
%  When replacing a rendering with a depth rendering, we assume that the
%  scene is in the replace slot, and the next one is the depth slot. If you
%  first rendered without depth, and then you change and add a depth, do
%  not use 'replace'.
%
% Inputs
%     obj:  A gCloud object
%   thisR: A rendering recipe
%
% Key/value options
%  replace: A particular target slot (1, 2 ... N) for this job.  Normally,
%           the target is appended to the existing targets.  When 'replace'
%           is set to an integer, it must be one of the existing slots.
%
% Returns
%   target:  This particular target, which has been placed in a slot
%
% ZL Vistateam, 2017
%   gCloud.targetsList
%   gCloud.targetDelete

%% Parse

varargin = ieParamFormat(varargin);

p = inputParser;
p.addRequired('obj',@(x)(isa(x,'gCloud')));
p.addRequired('thisR',@(x)(isa(x,'recipe') || exist(thisR,'file')));
p.addParameter('road',[]);
p.addParameter('replace',[],@(x)(x >= 1 && x <= (length(obj.targets)+1)));
p.addParameter('subjectlabel','',@ischar);
% p.addParameter('fname',@(x)(exist(fname,'file')));

p.parse(obj,thisR,varargin{:});

replace      = round(p.Results.replace);
road         = p.Results.road;
subjectLabel = p.Results.subjectlabel;

if ischar(thisR)
    % we load a saved target.json
    target = jsonread(thisR);
    %     obj.targets.fwAPI = scene_target.fwAPI;
    %     obj.targets.remote = scene_target.remote;
    %     obj.targets.local = scene_target.local;
else
    %% Act
    
    % When we loop and create various versions of the PBRT scene file, we
    % put all the versions into the same remote directory.  So we set up
    % the cloud folder on the input.
    % pbrtScene = thisR.get('input file');
    
    % -----Zhenyi
    % if ~exist(pbrtScene,'file'), error('PBRT scene not found %s\n',pbrtScene);
    % else,                       [~, sceneName] = fileparts(pbrtScene);
    % end
    
    % [~, sceneName] = fileparts(pbrtScene);
    %
    % cloudFolder = fullfile(obj.cloudBucket,obj.namespace,sceneName);
    
    % The output pbrt scene file is based on the output file, and this can
    % change.
    pbrtScene = thisR.get('output file');
    
    % [~, sceneName] = fileparts(pbrtScene);
    target.camera  = thisR.camera;
    
    % target.sceneInfo = sceneInfo;
    target.local   = pbrtScene;
    
    if isprop(obj, 'fwAPI')
        % If this slot exists, we are working with Flywheel storage
        % So we add this information.
        target.remote = obj.fwAPI.projectID;
        target.fwAPI = obj.fwAPI;
        if ~isempty(road)
            target.fwList = road.fwList;
        end
        % The output for the job will have its own subject label.  The
        % inputs are usually scene or camera array.  The output is
        % 'renderings' by default.
        target.fwAPI.subjectLabel = subjectLabel;
    else
        target.remote = fullfile(cloudFolder,sprintf('%s.pbrt',sceneName));
    end
    
    %% Indicate if this target is a depth map or not
    
    % This is used to sort returned targets when downloading.
    target.depthFlag = obj.renderDepth;
    target.meshFlag  = obj.renderMesh;
end

%% Decide which target we are changing
if isempty(replace)
    % Add the target to current list of targets
    obj.targets = cat(1,obj.targets,target);
    thisTarget = numel(obj.targets);
else
    % Replace an existing target
    if isempty(obj.targets) && replace == 1, obj.targets = target;
    elseif ~isempty(obj.targets),            obj.targets(replace) = target;
    else, error('Error replacing a target. %d',replace);
    end
    thisTarget = replace;
end

% If the user gave you a specific subject label, over-ride the current
% value
if ~isempty(subjectLabel)
    obj.targets(thisTarget).fwAPI.subjectLabel = subjectLabel;
end

end

%{
%% Add depth file if requested
% if(obj.renderDepth)
%     % We assume the depth is always the next target, after the scene
%     % render.  This is dangerous.  Say the person has a set of targets and
%     % then changes whether they are computing the depth.  We might be
%     % over-writing the next target.  Be fearful when you get here.
%     target.camera = thisR.camera;
%     target.local = pbrtScene;
%     target.remote = fullfile(cloudFolder,sprintf('%s_depth.pbrt',sceneName));
%     if ~isempty(road)
%         target.fwList = road.fwList;
%     end
%     target.depthFlag = 1;
%
%
%     % Add this target to the targets already stored.
%     if isempty(replace)
%         obj.targets = cat(1,obj.targets,target);
%     else
%         obj.targets(replace+1) = target;
%     end
%
% end
%% Add mesh file if requested
% if(obj.renderMesh)
%     % We assume the mesh is always the next target, after the scene
%     % render.  This is dangerous.  Say the person has a set of targets and
%     % then changes whether they are computing the depth.  We might be
%     % over-writing the next target.  Be fearful when you get here.
%     target.camera = thisR.camera;
%     target.local = pbrtScene;
%     target.remote = fullfile(cloudFolder,sprintf('%s_mesh.pbrt',sceneName));
%     if ~isempty(road)
%         target.fwList = road.fwList;
%     end
%     target.meshFlag = 1;
%
%
%     % Add this target to the targets already stored.
%     if isempty(replace)
%         obj.targets = cat(1,obj.targets,target);
%     else
%         obj.targets(replace+1) = target;
%     end
%
% end
%}
