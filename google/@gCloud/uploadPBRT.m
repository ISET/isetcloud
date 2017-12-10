function [ obj ] = uploadPBRT(obj, thisR, varargin )
% Upload a pbrt scene directory for rendering on the cluster
%
% Syntax
%   gcp.uploadPBRT(thisR,...)
%
% Input
%   scene:  A render recipe.
%
% Description
%  Zip all files except for the *.pbrt files from top level directory
%
% Example:
%   gcp.upload(thisR)
%
% HB/ZL,  Vistasoft

%%
p = inputParser;
p.addRequired(thisR,@(x)(isa(x,'recipe')));
p.addParameter('overwritezip',true,@islogical);
p.parse(thisR,varargin{:});

overwritezip = p.Results.overwritezip;

%% Package up the files for uploading to the k8s

% The output file is the scene pbrt file
[sceneFolder, sceneFile] = fileparts(thisR.get('output file'));

% The name of the folder containing the file
[~, sceneName] = fileparts(sceneFolder);

% We are going to make a zip file of the whole folder
zipFileName = sprintf('%s.zip',sceneName);

% Check if there is a zip file.  We might want to over-write it or
% not.
zipFiles = dir(fullfile(sceneFolder,'*.zip'));

if isempty(zipFiles) || length(zipFiles) > 1
    
    % List evertying in the scene folder
    allFiles = dir(sceneFolder);
    
    % Convert the listing into a set of file names, excluding the
    % listings that start with a dot (.)
    allFiles = cell2mat(strcat({allFiles(cellfun(@(x) x(1) ~= '.',{allFiles(:).name})).name},{' '}));

    % Remember where you are, but then change to the scene folder
    currentPath = pwd;
    cd(sceneFolder);
    
    % Zip stuff excluding 
    cmd = sprintf('zip -r %s %s -x *.jpg *.png *.pbrt *.dat *.zip',zipFileName,allFiles);
    system(cmd);
    
    cd(currentPath);  % Return
end


%%  Copy the local data to the k8s bucket storage

cloudFolder = fullfile(obj.cloudBucket,obj.namespace,sceneName);

cmd = sprintf('gsutil cp %s/%s %s/%s.pbrt %s/',sceneFolder,zipFileName,...
                                          sceneFolder,sceneFile,...
                                          cloudFolder);
system(cmd);

target.camera = thisR.camera;
target.local  = fullfile(sceneFolder,sprintf('%s.pbrt',sceneFile));
target.remote = fullfile(cloudFolder,sprintf('%s.pbrt',sceneFile));

obj.targets = cat(1,obj.targets,target);      


end

