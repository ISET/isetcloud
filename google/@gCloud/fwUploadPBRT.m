function [acqID,names] = fwUploadPBRT(obj, thisR, varargin )
% Upload a pbrt scene directory to flywheel for rendering on the cluster
%
% Syntax
%   [acqID,names] = gcp.fwUploadPBRT(thisR, ...)
%
% Description:
%   The piWrite function places a number of files in the rendering
%   directory.  These include the scene, geometry, material, and lens file
%   and texture files. The scene, geometry, and material files are.
%   fundamental. We call the other files (textures, lens, spds, ...other)
%   cgresources. 
%
%   This function collects the resources into a single zip file.  It then
%   uploads the scene, geometry, materials and zipped resources to the
%   gcloud bucket.
%
% Input
%   obj:    A gCloud object
%   thisR:  A render recipe.
%
% Optional key/value pairs
%   render project lookup -  lookup string for the render project; must
%     exist.  It will not be created.  By default the project is 
%            'Graphics auto renderings'
%   subject name     - string (default:  'scenes')
%   session name     - 
%   acquisition name -
%   road         - a struct describing the road (no default)
%   scitran      - @scitran object (empty default)
%
% Returns
%   acqID -  The Flywheel acquisition where the scene is stored
%   names -  Struct with the subject, session and acquisiton names
%
% Descriptions
%  Using the information in the render recipe (thisR), we find and zip
%  the resource files.  The zip file is placed inside the data
%  directory.
%
% Dependencies:  ISET3d
%
% Zhenyi Liu,  Vistalab
% 
% See also: s_gCloud, t_piRenderFW_cloud, t_piSceneAutoGeneration
%

% Examples:
%{
%}

%%

varargin = ieParamFormat(varargin);  % Allow spaces and capitalization

p = inputParser;
p.addRequired('recipe',@(x)(isa(x,'recipe')));
p.addParameter('road',@(x)(isempty(x) || isstruct(x)));   % What type of object should this be?

% users can specify the upload project using the following two parameters.
% The first is the name of the project.  The scene is the subject type of
% the project.  We use the subject field to distinguish the input (scene)
% and the output (rendering)
%
% To consider:
%    We might attach these parameters to the gcp as slots.  Other
%    information is attached below (line 172)
%       gcp.fw.project - The project (e.g., 'Graphics auto renderings')
%       gcp.fw.subject - The type of object (scene, asset, rendering)
%       gcp.fw.scitran - the scitran object
%
p.addParameter('renderprojectlookup','wandell/Graphics auto renderings',@ischar);
p.addParameter('subjectname','scenes',@ischar); 
p.addParameter('sessionname','',@ischar);
p.addParameter('acquisitionname','',@ischar);

% flywheel 
p.addParameter('scitran',[],@(x)(isa(x,'scitran')));

p.parse(thisR,varargin{:});

road          = p.Results.road;     % a struct representing the road
st            = p.Results.scitran;  % @scitran object

% Project lookup string.  Get the project and its ID
renderProjectLookup = p.Results.renderprojectlookup;

% If this does not exist, the call fails.  Make your project.
renderProject = st.lookup(renderProjectLookup);

obj.fwAPI.projectID = renderProject.id;

% Render subject name to use
subjectName  = p.Results.subjectname;         
sessionName  = p.Results.sessionname;
acquisitionName = p.Results.acquisitionname; 

% Return these if the user wants
if nargout > 1
    names.subject = subjectName;
    names.session = sessionName;
    names.acquisition = acquisitionName;
end

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
%% Write out pointCloud file, if required
if(obj.renderPointCloud)
    
    meshRecipe = piRecipeConvertToMetadata(thisR,'metadata','coordinates');
    
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

%% Need to specify subject

% We have to check whether the subject exists
group       = st.lookup(renderProject.group);

if isempty(sessionName)
    tmp = strsplit(sceneName,'_');
    sessionName = tmp{1};
end
if isempty(acquisitionName)
    acquisitionName = sceneName;
end

% We create the acquisition container
% 
idS = st.containerCreate(group.label,renderProject.label,...
    'subject',subjectName,...
    'session',sessionName,...
    'acquisition',acquisitionName);
acqID = idS.acquisition;

% For debugging
% st.fw.deleteSession(idS.session);

% thisSession  = sceneSubject.sessions.findOne(sprintf('label=%s',sessionName{1}));
% if isempty(thisSession)
%     thisSession  =  sceneSubject.addSession('label', sessionName{1});
% end
% thisAcq      = thisSession.addAcquisition('label', sceneName);
% current_id = thisAcq.id;

% Assign Flywheel information to gCloud object
obj.fwAPI.sceneFilesID  = acqID;
obj.fwAPI.key      = st.showToken;
obj.fwAPI.InfoList = road.fwList;

if ~isempty(acqID)
    fprintf('%s acquisition created \n', sceneName);
end
%% Start the upload to the specified acquisition

status= st.fileUpload(pbrtSceneFile,acqID,'acquisition');
if isempty(status)
    fprintf('%s.pbrt uploaded \n', sceneName);
else
    error('Upload of scene file to Flywheel failed\n');
end
%% Copy  material files to that acquisition
 
pbrtMaterialFile = fullfile(sceneFolder, sprintf('%s_materials.pbrt', sceneName));

status= st.fileUpload(pbrtMaterialFile,acqID, 'acquisition');
if  isempty(status)
    fprintf('%s uploaded \n',sprintf('%s_materials.pbrt', sceneName));
else
    error('cp scene materials file to flywheel failed\n');
end
%% Copy  geometry files to the acquisition

pbrtGeometryFile = fullfile(sceneFolder,sprintf('%s_geometry.pbrt',sceneName));

status= st.fileUpload(pbrtGeometryFile,acqID,'acquisition');
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
    status          = st.fileUpload(pbrtDepthFile,acqID,'acquisition');
    status_geometry = st.fileUpload(pbrtDepthGeometryFile, acqID, 'acquisition');
    if isempty(status)|| isempty(status_geometry) 
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
    status          = st.fileUpload(pbrtMeshFile,acqID,'acquisition');
    status_geometry = st.fileUpload(pbrtMeshGeometryFile, acqID, 'acquisition');
    if  isempty(status) || isempty(status_geometry)
        fprintf('%s uploaded \n',f_mesh);
    else
        error('cp Mesh scene file to flywheel failed\n');
    end
end
%% Copy point cloud file
if(obj.renderPointCloud)
    
    f_coord  = sprintf('%s_coordinates.pbrt',sceneName);
    pbrtCoordFile = fullfile(sceneFolder,f_coord);
    pbrtCoordGeometryFile = fullfile(sceneFolder,sprintf('%s_coordinates_geometry.pbrt', sceneName));
    status          = st.fileUpload(pbrtCoordFile,acqID,'acquisition');
    status_geometry = st.fileUpload(pbrtCoordGeometryFile, acqID, 'acquisition');
    if  isempty(status) || isempty(status_geometry)
        fprintf('%s uploaded \n', f_coord);
    else
        error('cp PointCloud scene file to flywheel failed\n');
    end
end
%% Upload the recipe JSON file
% This file contains all of the cgresource information needed to
% create the scene

recipeJson     = sprintf('%s.json', sceneName);
pbrtRecipeJson = fullfile(sceneFolder, recipeJson);
status         = st.fileUpload(pbrtRecipeJson,acqID,'acquisition');
if  isempty(status)
    fprintf('%s uploaded \n', recipeJson);
else
    error('cp recipeJson of scene file to flywheel failed\n');
end

%% Save and upload <name>_target.json file

% This file contains the IDs needed to recreate the scene using the
% data in Flywheel
target.camera    = thisR.camera;
target.local     = thisR.outputFile;
target.remote    = obj.fwAPI.projectID;
target.fwAPI     = obj.fwAPI;
target.depthFlag = obj.renderDepth;
target.meshFlag  = obj.renderMesh;
target.coordinateFlag = obj.renderPointCloud;
targetJsonName = sprintf('%s_target.json',sceneName);
targetJson=fullfile(sceneFolder,targetJsonName);
jsonwrite(targetJson,target);
status= st.fileUpload(targetJson,acqID,'acquisition');
if  isempty(status)
    fprintf('%s uploaded \n',targetJsonName);
else
    error('cp targetJson of scene file to flywheel failed\n');
end

disp('*** All files uploaded to Flywheel. ***')
end

