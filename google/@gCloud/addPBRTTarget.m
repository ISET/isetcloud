function target = addPBRTTarget(obj,thisR)
% Add a PBRT target job to the google cloud engine instance
%
% ZL Vistateam, 2017

%% Parse


%% Act

% When we loop and create various versions of the PBRT scene file, we
% put all the versions into the same remote directory.  So we set up
% the cloud folder on the input.
pbrtScene = thisR.get('input file');
if ~exist(pbrtScene,'file'), error('PBRT scene not found %s\n',pbrtScene);
else,                       [~, sceneName] = fileparts(pbrtScene);
end
cloudFolder = fullfile(obj.cloudBucket,obj.namespace,sceneName);

% The output pbrt scene file is based on the output file, and this can
% change.
pbrtScene = thisR.get('output file');
[~, sceneName] = fileparts(pbrtScene);
target.camera = thisR.camera;
target.local = pbrtScene;
target.remote = fullfile(cloudFolder,sprintf('%s.pbrt',sceneName));

% Add this target to the targets already stored.
obj.targets = cat(1,obj.targets,target);

%% Add depth file if necessary
if(obj.renderDepth)
    
    target.camera = thisR.camera;
    target.local = pbrtScene;
    target.remote = fullfile(cloudFolder,sprintf('%s_depth.pbrt',sceneName));
    
    % Add this target to the targets already stored.
    obj.targets = cat(1,obj.targets,target);
    
end

end
