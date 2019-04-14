function [sceneSession,current_id] = fwUploadPBRT(obj, thisR, varargin )
% Upload a pbrt scene directory to flywheel for rendering on the cluster
%
% Syntax
%   [sceneSession,current_id] = gcp.fwUploadPBRT(thisR, ...)
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
%   road
%   scitran
%
% Returns
%   sceneSession - The bucket where the files were copied
%   current_id   - ID of the acquisition created for the upload.
%
% Descriptions
%  Using the information in the render recipe (thisR), we find and zip
%  the resource files.  The zip file is placed inside the data
%  directory.
%
%
%  The 'target' field of the gcp object is modified to specify the
%
% See examples in source code
%
% See also: s_gCloud
%
% ZL,  Vistasoft
% 
% See also:
%   

% We assume gcp is initialized
%
% Example 1
%{
%}

%%

varargin = ieParamFormat(varargin);  % Allow spaces and capitalization

p = inputParser;
p.addRequired('recipe',@(x)(isa(x,'recipe')));
p.addParameter('road',[]);

% flywheel 
p.addParameter('scitran',[],@(x)(isa(x,'scitran')));

p.parse(thisR,varargin{:});

road         = p.Results.road;
st           = p.Results.scitran;     % flywheel
%% Write out the depth file, if required
if(obj.renderDepth)
    
    depthRecipe = piRecipeConvertToMetadata(thisR,'metadata','depth');
    
    % Always overwrite the depth file, but don't copy over the whole directory
    piWrite(depthRecipe,...
        'overwritepbrtfile',true,...
        'overwritelensfile',false,...
        'overwriteresources',false,...
        'overwritematerials',false,...
        'creatematerials',true,...
        'overwritegeometry',true);
end

%% Write out the mesh file, if required
if(obj.renderMesh)
    
    meshRecipe = piRecipeConvertToMetadata(thisR,'metadata','mesh');
    
    % Always overwrite the mesh file, but don't copy over the whole directory
    piWrite(meshRecipe,...
        'overwritepbrtfile',true,...
        'overwritelensfile',false,...
        'overwriteresources',false,...
        'overwritematerials',false,...
        'creatematerials',true,...
        'overwritegeometry',true);
end

%% These are the PBRT scene file and resources
% pbrtScene = thisR.get('input file');
%% Render recipe is created by json file on flywheel, so no input pbrtScene file for this case --zhenyi0908
% if ~exist(pbrtScene,'file')
%     error('PBRT scene not found %s\n',pbrtScene);
% else
%     [sceneFolder, sceneName] = fileparts(pbrtScene);
% end

%%  Copy the local data to flywheel 'scenes_pbrt' session, create an acquisition named by scene name;
pbrtSceneFile = thisR.get('output file');
[sceneFolder,sceneName,~]= fileparts(pbrtSceneFile);

if ~exist(pbrtSceneFile,'file')
    error('Could not find pbrt scene file %s\n',pbrtSceneFile);
end

% Identify the project
project = st.lookup('wandell/Graphics assets');

% Identify the session
sceneSession = project.sessions.findOne('label=scenes_pbrt');

% Create an acquisition
%{
%}

% This should be updated.  The return is a struct with three IDs for the
% project, session and acquisition.  It takes too long to run now because
% containerCreate uses the old 'exist' method.  After we speed that up, we
% should fix this code to go faster as well.
current_id = st.containerCreate('Wandell Lab', 'Graphics assets',...
    'session','scenes_pbrt',...
    'acquisition',sceneName);

% Assign Flywheel information to gCloud object
obj.fwAPI.sceneFilesID  = current_id;
obj.fwAPI.key = st.showToken;
obj.fwAPI.InfoList = road.fwList;

fwproject = st.search('project','project label exact','Renderings');
obj.fwAPI.projectID = fwproject{1}.project.id;

if ~isempty(current_id.acquisition)
    % Prefer that we use 
    % thisAcq = st.get(current_id);
    % fprintf('%s acquisition created \n',thisAcq.label);
    fprintf('%s acquisition created \n',sceneName);
end

%% Start the upload
status= st.fileUpload(pbrtSceneFile,current_id.acquisition,'acquisition');
if isempty(status)
    fprintf('%s.pbrt uploaded \n',sceneName);
else
    error('Upload of scene file to Flywheel failed\n');
end

%% Copy  material files
 
pbrtMaterialFile = fullfile(sceneFolder,sprintf('%s_materials.pbrt',sceneName));

status= st.fileUpload(pbrtMaterialFile,current_id.acquisition,'acquisition');
if  isempty(status)
    fprintf('%s uploaded \n',sprintf('%s_materials.pbrt',sceneName));
else
    error('cp scene materials file to flywheel failed\n');
end

%% Copy  geometry files

pbrtGeometryFile = fullfile(sceneFolder,sprintf('%s_geometry.pbrt',sceneName));

status= st.fileUpload(pbrtGeometryFile,current_id.acquisition,'acquisition');
if  isempty(status)
    fprintf('%s uploaded \n',sprintf('%s_geometry.pbrt',sceneName));
else
    error('cp scene geometry file to flywheel failed\n');
end

%% Copy depth file
if(obj.renderDepth)
    f_depth  = sprintf('%s_depth.pbrt',sceneName);
    pbrtDepthFile = fullfile(sceneFolder,f_depth);
    pbrtDepthGeometryFile = fullfile(sceneFolder,sprintf('%s_depth_geometry.pbrt',sceneName));
    status= st.fileUpload(pbrtDepthFile,current_id.acquisition,'acquisition');
    status_geometry= st.fileUpload(pbrtDepthGeometryFile,current_id.acquisition,'acquisition');
    if isempty(status) || isempty(status_geometry)
        fprintf('%s uploaded \n',f_depth);
    else
        error('cp Depth scene file to flywheel failed\n');
    end
end

%% Copy mesh file
if(obj.renderDepth)
    
    f_mesh  = sprintf('%s_mesh.pbrt',sceneName);
    pbrtMeshFile = fullfile(sceneFolder,f_mesh);
    pbrtMeshGeometryFile = fullfile(sceneFolder,sprintf('%s_mesh_geometry.pbrt',sceneName));
    status= st.fileUpload(pbrtMeshFile,current_id.acquisition,'acquisition');
    status_geometry= st.fileUpload(pbrtMeshGeometryFile,current_id.acquisition,'acquisition');
    if  isempty(status) || isempty(status_geometry)
        fprintf('%s uploaded \n',f_mesh);
    else
        error('cp Mesh scene file to flywheel failed\n');
    end
end
%% piGeometryRead creates a json file of current recipe, upload recipe.

recepeJson = sprintf('%s.json',sceneName);
pbrtRecipeJson = fullfile(sceneFolder,recepeJson);
status= st.fileUpload(pbrtRecipeJson,current_id.acquisition,'acquisition');
if  isempty(status)
    fprintf('%s uploaded \n',recepeJson);
else
    error('cp recipeJson of scene file to flywheel failed\n');
end

%% save and upload gcp.target json file

target.camera    = thisR.camera;
target.local     = thisR.outputFile;
target.remote    = obj.fwAPI.projectID;
target.fwAPI     = obj.fwAPI;
target.depthFlag = obj.renderDepth;
target.meshFlag  = obj.renderMesh;
targetJsonName = sprintf('%s_target.json',sceneName);
targetJson=fullfile(sceneFolder,targetJsonName);
jsonwrite(targetJson,target);
status= st.fileUpload(targetJson,current_id.acquisition,'acquisition');
if  isempty(status)
    fprintf('%s uploaded \n',targetJsonName);
else
    error('cp targetJson of scene file to flywheel failed\n');
end

disp('*** All files uploaded to Flywheel. ***')
end

