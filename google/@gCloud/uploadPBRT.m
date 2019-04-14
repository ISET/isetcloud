function [cloudFolder,zipFileName] = uploadPBRT(obj, thisR, varargin )
% Upload a pbrt scene directory for rendering on the cluster
%
% Syntax
%   [cloudFolder,zipFileName] = gcp.uploadPBRT(thisR, ...)
%
% Description:
%   The piWrite function places a number of files in the rendering
%   directory.  These include the scene, geometry, material, and lens file
%   and texture files. The scene, geometry, and material files are.
%   fundamental. We call the other files (textures, lens, spds, ...other)
%   resources. 
%
%   This function collects the resources into a single zip file.  It then
%   uploads the scene, geometry, materials and zipped resources to the
%   gcloud bucket.
%
% Input
%   thisR:  A render recipe.
%
% Optional key/value pairs
%
%   materials - upload materials.pbrt, default is true
%   geometry  - upload geomety.pbrt, default is true
%   resources - upload rendering dependent files, default is true
%
% Returns
%   cloudFolder - The bucket where the files were copied
%   zipFileName - The name of the resources zip file
%
% Descriptions
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

% Special name for the zip resources file
p.addParameter('zipfilename','',@ischar);

% Specify whether we overwrite the zip resources file
p.addParameter('overwritezip',true,@islogical);

% Specify whether we upload a *_materials.pbrt
p.addParameter('materials',true,@islogical);  

% Specify whether we upload a *_geometry.pbrt
p.addParameter('geometry',true,@islogical); 

% Specify whether we upload the zipped resources file
p.addParameter('resources',true,@islogical);

p.parse(thisR,varargin{:});

overwritezip = p.Results.overwritezip;  % This refers to the local zip
materials    = p.Results.materials;     % Upload materials files (logical)
geometry     = p.Results.geometry;      % Upload geometry files (logical)
resources    = p.Results.resources;     % This refers to the cloud zip
zipFileName  = p.Results.zipfilename;   % This refers to the cloud zip

%% Write out the depth file, if required
if(obj.renderDepth)
    
    depthRecipe = piRecipeConvertToMetadata(thisR,'metadata','depth');
    
    % Depending on whether we used C4D to export, we create a new
    % material files that we link with the main pbrt file.
    if(strcmp(depthRecipe.exporter,'C4D'))
        creatematerials = true;
    else
        creatematerials = false;
    end
    
    % Always overwrite the depth file, but don't copy over the whole
    % directory.
    piWrite(depthRecipe,...

        'overwritepbrtfile',true,...
        'overwritelensfile',false,...
        'overwriteresources',false,...
        'overwritegeometry',false);
end

%% Write out the mesh file, if required
if(obj.renderMesh)
    
    meshRecipe = piRecipeConvertToMetadata(thisR,'metadata','mesh');
    
    % Always overwrite the depth file, but don't copy over the whole directory
    piWrite(meshRecipe,...
        'overwritepbrtfile',true,...
        'overwritelensfile',false,...
        'overwriteresources',false,...
        'overwritegeometry',false);
end

%% Package up the files for uploading to the k8s

% When this step is done, we will have a
%  * scene file
%  * geometry file
%  * material file
%  * a zipped resources file

% These are the PBRT scene file and resources
pbrtScene = thisR.get('input file');
%% Render recipe is created by json file on flywheel, so no input pbrtScene file for this case --zhenyi0908
% if ~exist(pbrtScene,'file')
%     error('PBRT scene not found %s\n',pbrtScene);
% else
%     [sceneFolder, sceneName] = fileparts(pbrtScene);
% end
%%
[sceneFolder, sceneName] = fileparts(pbrtScene);
% We will make a zip file of the whole folder.  If it wasn't passed,
% use this as the default
if resources
if isempty(zipFileName)
    % Always based on the input file, not the output file.
    pbrtScene = thisR.get('input file');
    [~, sceneName] = fileparts(pbrtScene);
    zipFileName = [sceneName,'.zip'];
end

zipFileFullPath = fullfile(sceneFolder,zipFileName);
if exist(zipFileFullPath,'file') && ~overwritezip
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
    
    % Zip recursively so that renderings/ is there
    % but exclude
    %   contents of the renderings folder
    %   zip files
    %   jpg files - 
    %   zip files 
    %   pbrt files
    % If output file (zipFileName) is already present, this command
    % updates the file contents.
    fprintf('Zipping into %s\n',zipFileName);
    cmd = sprintf('zip -r %s %s -x *.jpg *.pbrt renderings/* *.zip *.json',zipFileName,allFiles);
    status = system(cmd);
    
    % When there are no resource files, the zip file is empty and status is
    % true.
    if status
        warning('No files zipped. Assuming empty.');
        zipFileFullPath = '';
        resources = false;
    else
        if ~exist(zipFileFullPath,'file')
            error('Something wrong in producing the zip file %s\n',zipFileFullPath);
        end
    end
    
    cd(currentPath);  % Return
end
else
    disp('*******Zipping Skipped******');
end
%%  Copy the local data to the k8s bucket storage

pbrtSceneFile = thisR.get('output file');
[p,f,~]= fileparts(pbrtSceneFile);

if ~exist(pbrtSceneFile,'file')
    error('Could not find pbrt scene file %s\n',pbrtSceneFile);
end

% Build the command for uploading resources and scene file
cloudFolder = fullfile(obj.cloudBucket,obj.namespace,sceneName);
if resources
    % We want to copy the resources
    % Copy the zip file and the pbrt file
    cmd = sprintf('gsutil cp %s %s %s/',  ...
        zipFileFullPath,...
        pbrtSceneFile,...
        cloudFolder);
else
    % No resources for upload.  Command sends up only PBRT scene file
    cmd = sprintf('gsutil cp  %s %s/',pbrtSceneFile,...
        cloudFolder);
end

% Do the copy and check
[status, result] = system(cmd);
if status
    error('cp scene file (and possibly zip file) to cloud bucket failed\n %s',result);
end

%% Copy geometry and material files

% BW - The logic here seems flawed to me.  I do not understand how we are
% using the materials flag and also testing for a material file.  If the
% file pbrtMaterialFile exists, we should upload it.  There should be only
% one (or multiple?) material files?  Anyway, we need to deal with this.
%
% For materials and geometry we will use a wildcard. These files are
% usually named after the original pbrt file name, and not scene file named
% specific in iset3d. In the docker container we also copy over all
% material and geometry files using a wildcard. This may not be the most
% efficient way, but it ensures the file gets in there somehow. 
pbrtMaterialFile = fullfile(p,'*_materials.pbrt');
pbrtGeometryFile = fullfile(p,'*_geometry.pbrt');

if(numel(dir(pbrtMaterialFile))) > 0 && materials
    cmd = sprintf('gsutil cp  %s %s/',pbrtMaterialFile,...
        cloudFolder);
    [status, result] = system(cmd);
    if status
        warning('Material file cp to cloud folder failed\n %s',result);
    end
end

if(numel(dir(pbrtGeometryFile))) > 0 && geometry
    cmd = sprintf('gsutil cp  %s %s/',pbrtGeometryFile,...
        cloudFolder);
    [status, result] = system(cmd);
    if status
        error('Geometry file cp to cloud folder failed\n %s',result);
    end
end

%% Copy depth file
if(obj.renderDepth)
    
    f_depth  = sprintf('%s_depth.pbrt',f);
    pbrtDepthFile = fullfile(p,f_depth);
    cmd = sprintf('gsutil cp  %s %s/',pbrtDepthFile,...
        cloudFolder);
    [status, result] = system(cmd);
    if status
        error('Depth file cp to cloud folder failed\n %s',result);
    end
    
end

%% Copy mesh file
if(obj.renderDepth)
    
    f_mesh  = sprintf('%s_mesh.pbrt',f);
    pbrtMeshFile = fullfile(p,f_mesh);
    cmd = sprintf('gsutil cp  %s %s/',pbrtMeshFile,...
        cloudFolder);
    [status, result] = system(cmd);
    if status
        error('Mesh file cp to cloud folder failed\n %s',result);
    end
    
end


end

