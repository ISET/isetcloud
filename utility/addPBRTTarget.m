function target = addPBRTTarget(gce,thisR)
% Add a PBRT target job to the google cloud engine instance
%
% ZL Vistateam, 2017

%% Parse


%% Act

pbrtScene = thisR.get('output file');
if ~exist(pbrtScene,'file'), error('PBRT scene not found %s\n',pbrtScene);
else,                       [~, sceneName] = fileparts(pbrtScene);
end

cloudFolder = fullfile(gce.cloudBucket,gce.namespace,sceneName);

target.camera = thisR.camera;
target.local = pbrtScene;
target.remote = fullfile(cloudFolder,sprintf('%s.pbrt',sceneName));

% Add this target to the targets already stored.
gce.targets = cat(1,gce.targets,target);

end
