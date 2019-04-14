function target = addPBRTTarget(obj, thisR, sceneInfo,varargin)
% Add a PBRT target job to the google cloud engine instance
%
% Syntax
%    target = addPBRTTarget(obj,thisR, varargin);
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

%% Parse
p = inputParser;
p.addRequired('obj',@(x)(isa(x,'gCloud')));
p.addRequired('thisR',@(x)(isa(x,'recipe')));
% pass the fwList info in.
p.addParameter('road',[]);
% We add to an existing slot, or we allow it to append to the end.
p.addParameter('replace',[],@(x)(x >= 1 && x <= (length(obj.targets)+1)));
p.parse(obj,thisR,varargin{:});

replace = round(p.Results.replace);
road = p.Results.road;
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
% target.remote = fullfile(cloudFolder,sprintf('%s.pbrt',sceneName));
target.remote = obj.fwAPI.projectID;
target.fwAPI = obj.fwAPI;
if ~isempty(road)
    target.fwList = road.fwList;
end
 % Indicate if this target is a depth map or not. This is used to sort between returned targets when downloading. 

target.depthFlag = obj.renderDepth;
target.meshFlag  = obj.renderMesh;
% Add this target to the targets already stored.
if isempty(replace),   obj.targets = cat(1,obj.targets,target);
else
    if isempty(obj.targets) && replace == 1, obj.targets = target;
    elseif ~isempty(obj.targets),            obj.targets(replace) = target;
    else, error('Error replacing a target. %d',replace);
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
end
