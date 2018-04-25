function [cloudFolder,zipFileName] = uploadPBRT(obj, thisR, varargin )
% Upload a pbrt scene directory for rendering on the cluster
%
% Syntax
%   [cloudFolder,zipFileName] = gcp.uploadPBRT(thisR, ...)
%
% Input
%   thisR:  A render recipe.
%
% Description
%  Using the information in the render recipe (thisR), we find and zip
%  the resource files.  The zip file is placed inside the data
%  directory. 
%
%  We then copy the zip file with the resources and the pbrt scene
%  file (*.pbrt) to the gcp  bucket.
%
%  The 'target' field of the gcp object is modified to specify the
%
% See examples in source code
%
% See also: s_gCloud
%
% HB/ZL,  Vistasoft

% We assume gcp is initialized
%
% Example 1
%{
  % The chess set scene has resource files
  fname = fullfile(piRootPath,'data','ChessSet','chessSet.pbrt');
  if ~exist(fname,'file'), error('File not found'); end
  thisR = piRead(fname);
  cloudFolder = gcp.uploadPBRT(thisR);
  gcp.ls(cloudFolder)
%}

% Example 2
%{
  % No resources files for teapot case
  fname = fullfile(piRootPath,'data','teapot-area','teapot-area-light.pbrt');
  if ~exist(fname,'file'), error('File not found'); end
  thisR = piRead(fname);
  cloudFolder = gcp.uploadPBRT(thisR);
  gcp.ls(cloudFolder)
%}

%%
p = inputParser;

varargin = ieParamFormat(varargin);  % Allow spaces and capitalization

p.addRequired('recipe',@(x)(isa(x,'recipe')));
p.addParameter('overwritezip',true,@islogical);
p.addParameter('uploadzip',true,@islogical);
p.addParameter('zipfilename','',@ischar);

p.parse(thisR,varargin{:});

overwritezip = p.Results.overwritezip;  % This refers to the local zip
uploadzip    = p.Results.uploadzip;     % This refers to the cloud zip
zipFileName  = p.Results.zipfilename;     % This refers to the cloud zip

%% Package up the files for uploading to the k8s

% These are the PBRT scene file and resources
pbrtScene = thisR.get('output file');
if ~exist(pbrtScene,'file')
    error('PBRT scene not found %s\n',pbrtScene);
else
    [sceneFolder, sceneName] = fileparts(pbrtScene);
end

% We will make a zip file of the whole folder.  If it wasn't passed,
% use this as the default
if isempty(zipFileName)
    % Always based on the input file, not the output file.
    pbrtScene = thisR.get('input file');
    [~, sceneName] = fileparts(pbrtScene);
    zipFileName = [sceneName,'.zip'];
end

if exist(zipFileName,'file') && ~overwritezip
    % Skip zipping
else
    currentPath = pwd; chdir(sceneFolder);

    % List all the files in the scene folder
    %     if ~exist(sceneFolder,'dir')
    %     end
    allFiles = dir(sceneFolder);
    
    % Convert the listing into a set of file names, excluding the
    % listings that start with a dot (.)
    allFiles = cell2mat(strcat({allFiles(cellfun(@(x) x(1) ~= '.',{allFiles(:).name})).name},{' '}));
    
    % Remember where you are, and then change to the scene folder
    
    % Zip recursively but excluding certain file types and any other
    % zip files that might have been put here.
    fprintf('Zipping into %s\n',zipFileName);
    cmd = sprintf('zip -r %s %s -x *.jpg *.pbrt renderings/* *.zip',zipFileName,allFiles);
    status = system(cmd);
    
    % When there are no resource files, the zip file is empty
    if status
        warning('No files zipped. Assuming empty.');
        zipFileName = '';
    end
    zipFileFullPath = fullfile(sceneFolder,zipFileName);
    if ~exist(zipFileFullPath,'file')
        error('Something wrong in producing the zip file %s\n',zipFileFullPath);
    end
    
    cd(currentPath);  % Return
end

%%  Copy the local data to the k8s bucket storage

pbrtSceneFile = thisR.get('output file');
[p,f,~]= fileparts(pbrtSceneFile);
f_materials = sprintf('%s_materials.pbrt',f);
pbrtMaterialFile = fullfile(p,f_materials);
f_geometry = sprintf('%s_geometry.pbrt',f);
pbrtGeometryFile = fullfile(p,f_geometry);
if ~exist(pbrtSceneFile,'file')
    error('Could not find pbrt scene file %s\n',pbrtSceneFile);
end

cloudFolder = fullfile(obj.cloudBucket,obj.namespace,sceneName);
if isempty(zipFileName) || ~uploadzip
    % Either no zip file or we are told not to upload the zip.
    % So we only copy the pbrt scene file
    cmd = sprintf('gsutil cp  %s %s/',pbrtSceneFile,...
                                      cloudFolder);
else
    % Copy the zip file and the pbrt file
    cmd = sprintf('gsutil cp %s %s %s/',  zipFileFullPath,...
                                          pbrtSceneFile,...
                                          cloudFolder);
end

% Do the copy and check
[status, result] = system(cmd);
if status
    error('cp to cloud folder failed\n %s',result);
end
if exist(pbrtMaterialFile, 'file')
    cmd = sprintf('gsutil cp  %s %s/',pbrtMaterialFile,...
                                         cloudFolder);
[status, result] = system(cmd);
if status
    error('Material file cp to cloud folder failed\n %s',result);
end
end
if exist(pbrtGeometryFile, 'file')
    cmd = sprintf('gsutil cp  %s %s/',pbrtGeometryFile,...
                                         cloudFolder);
[status, result] = system(cmd);
if status
    error('Geometry file cp to cloud folder failed\n %s',result);
end
end
% obj.ls(cloudFolder)


end

