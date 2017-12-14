function status = uploadPBRT(obj, thisR, varargin )
% Upload a pbrt scene directory for rendering on the cluster
%
% Syntax
%   status = gcp.uploadPBRT(thisR, ...)
%
% Input
%   thisR:  A render recipe.
%
% Description
%  Using the information in the render recipe, we find and zip the
%  resource files.  Only the pbrt scene files (*.pbrt files) from top
%  level directory are not zipped. The files are uploaded to the gcp
%  bucket. The 'target' field of the gcp object is modified to specify
%  the
%
% Example:
%   gcp.uploadPBRT(thisR)
%
% NOTE:
% If only *.pbrt files are used to render the scene, then there will be no
% files to zip, an alternative command is used in this case.
%
% HB/ZL,  Vistasoft

% Example
%{
  % We assume gcp is initialized
  fname = fullfile(piRootPath,'data','ChessSet','chessSet.pbrt');
  if ~exist(fname,'file'), error('File not found'); end
  thisR = piRead(fname);
  gcp.uploadPBRT(thisR);

%}
%%
p = inputParser;

p.addRequired('recipe',@(x)(isa(x,'recipe')));
p.addParameter('overwritezip',true,@islogical);
p.parse(thisR,varargin{:});

overwritezip = p.Results.overwritezip;

%% Package up the files for uploading to the k8s

% These are the PBRT scene file and resources
[sceneFolder, sceneFile] = fileparts(thisR.get('input file'));

% The name of the folder containing the PBRT scene file
[~, sceneName] = fileparts(sceneFolder);

% We will make a zip file of the whole folder
shortName = sprintf('%s.zip',sceneName);
dataFolder = fileparts(sceneFolder);
zipFileName = fullfile(dataFolder,shortName);
if exist(zipFileName,'file') && ~overwritezip
%   Skip zipping
else

% Check if there is a zip file.  We might want to over-write it or not.
% zipFiles = dir(fullfile(sceneFolder,'*.zip'));

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
    [status, ~] = system(cmd);
    
    % Check on status should go here
    if status
    end
    %
    cd(currentPath);  % Return
end


% if isempty(zipFiles) || length(zipFiles) > 1
%     
%     % List evertying in the scene folder
%     allFiles = dir(sceneFolder);
%     
%     % Convert the listing into a set of file names, excluding the
%     % listings that start with a dot (.)
%     allFiles = cell2mat(strcat({allFiles(cellfun(@(x) x(1) ~= '.',{allFiles(:).name})).name},{' '}));
% 
%     % Remember where you are, but then change to the scene folder
%     currentPath = pwd;
%     cd(sceneFolder);
%     
%     % Zip stuff excluding 
%     cmd = sprintf('zip -r %s %s -x *.jpg *.png *.pbrt *.dat *.zip',zipFileName,allFiles);
%     [status, ~] = system(cmd);
%     
%     % Check on status should go here
%     if status
%     end
%     %
%     cd(currentPath);  % Return
% end

end

%%  Copy the local data to the k8s bucket storage
cloudFolder = fullfile(obj.cloudBucket,obj.namespace,sceneName);
zipFiles    = dir(fullfile(sceneFolder,'*.zip'));

if isempty(zipFiles)
    cmd = sprintf('gsutil cp  %s/%s.pbrt %s/',sceneFolder,sceneFile,cloudFolder);
else
    cmd = sprintf('gsutil cp %s/%s %s/%s.pbrt %s/',sceneFolder,zipFileName,...
                                          sceneFolder,sceneFile,...
                                          cloudFolder);
end
[status, ~] = system(cmd);

%% Fill the target slot with  information necessary for rendering

target.camera = thisR.camera;
target.local  = fullfile(sceneFolder,sprintf('%s.pbrt',sceneFile));
target.remote = fullfile(cloudFolder,sprintf('%s.pbrt',sceneFile));

obj.targets = cat(1,obj.targets,target);      


end

