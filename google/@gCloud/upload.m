function [ obj ] = uploadPBRT( obj, scene )
% Upload a pbrt scene directory for rendering on the cluster
%
% Syntax
%   gcp.uploadPBRT(scene)
%
% Input
%   scene:  This should be a render recipe.
%
% Description
%  Zip all files except for the *.pbrt files from top level directory
%
% Example:
%   gcp.upload(thisR)
%
% HB/ZL,  Vistasoft

% The output file is the scene pbrt file
[sceneFolder, sceneFile] = fileparts(scene.outputFile);
[~, sceneName] = fileparts(sceneFolder);

% We 
zipFileName = sprintf('%s.zip',sceneName);

% Check if there is a zip file
zipFiles = dir(fullfile(sceneFolder,'*.zip'));

if isempty(zipFiles) || length(zipFiles) > 1
    
    allFiles = dir(sceneFolder);
    allFiles = cell2mat(strcat({allFiles(cellfun(@(x) x(1) ~= '.',{allFiles(:).name})).name},{' '}));


    currentPath = pwd;
    cd(sceneFolder);
    cmd = sprintf('zip -r %s %s -x *.jpg *.png *.pbrt *.dat *.zip',zipFileName,allFiles);
    system(cmd);
    cd(currentPath);
end

cloudFolder = fullfile(obj.cloudBucket,obj.namespace,sceneName);

cmd = sprintf('gsutil cp %s/%s %s/%s.pbrt %s/',sceneFolder,zipFileName,...
                                          sceneFolder,sceneFile,...
                                          cloudFolder);
system(cmd);

target.camera = scene.camera;
target.local = fullfile(sceneFolder,sprintf('%s.pbrt',sceneFile));
target.remote = fullfile(cloudFolder,sprintf('%s.pbrt',sceneFile));

obj.targets = cat(1,obj.targets,target);      


end
