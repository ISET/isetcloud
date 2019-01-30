function isetObj = downloadPBRT( obj, thisR, varargin )
% Download data from gcloud bucket, returning *.dat files as ISET objects
% 
% Syntax:
%  gcp.downloadPBRT(thisR);
%  
% Input (required)
%   thisR:  A render recipe.
%    
% Inputs (optional)
%   scaleIlluminance -  if true, we scale the mean illuminance by the pupil
%                       diameter in piDat2ISET 
%
% Return
%  isetObj - a cell array of ISET scene or oi (depending on the recipe
%            optics)
%
% TL/ZL, Vistalab 2017
%
% See also: piDat2ISET

%%
p = inputParser;

varargin = ieParamFormat(varargin);

p.addRequired('thisR',@(x)(isequal(class(x),'recipe') || ischar(x)));

p.addParameter('scaleIlluminance',true,@islogical);

p.parse(thisR,varargin{:});
scaleIlluminance = p.Results.scaleIlluminance;

%%

isetObj = cell(1,length(obj.targets));

% We return a file for each of the gcloud targets
for t=1:length(obj.targets)
    
    if(obj.targets(t).depthFlag)
        % We skip the depth map for now. Later when we encounter a radiance
        % target we will look for the corresponding depth map and load it
        % then. See below.
        continue;
    end
        
    % This is where the data started
    [targetFolder]  = fileparts(thisR.get('outputfile'));
    
    % The targets slot contains the fullpath to the output on the
    % cloud
    [remoteFolder, remoteFile] = fileparts(obj.targets(t).remote);
    
    % Command to download from cloud to local directory
    cmd = sprintf('gsutil cp %s/renderings/%s.dat %s/renderings/%s.dat',...
        remoteFolder,remoteFile,targetFolder,remoteFile);
    
    % Do it
    [status, result] = system(cmd);
    if status
        disp(result)
    end
    
    % Convert the dat file to an ISET format
    outFile = sprintf('%s/renderings/%s.dat',targetFolder,remoteFile);
    
    % Convert radiance to optical image
    ieObject = piDat2ISET(outFile,...
        'label','radiance',...
        'recipe',thisR,...
        'scaleIlluminance',scaleIlluminance);
    
    % Look for the corresponding depth file (if necessary)
    if(obj.renderDepth)
        cmd = sprintf('gsutil cp %s/renderings/%s_depth.dat %s/renderings/%s_depth.dat',...
            remoteFolder,remoteFile,targetFolder,remoteFile);
        
        % Do it
        [status, result] = system(cmd);
        if status
            disp(result)
            warning('Could not download depth map: %s/renderings/%s_depth.dat',remoteFolder,remoteFile);
        end
        
        % Read the downloaded depth file
         depthOutFile = sprintf('%s/renderings/%s_depth.dat',targetFolder,remoteFile);
        
         depthImage = piDat2ISET(depthOutFile,'label','depth');
         if ~isempty(ieObject) && isstruct(ieObject)
             ieObject = sceneSet(ieObject,'depth map',depthImage);
         end
         
    end

    isetObj{t} = ieObject;
    
end

% Clear empty cells in isetObj that were created from depth map targets
if(obj.renderDepth)
    isetObj = isetObj(~cellfun('isempty',isetObj)) ;
end

end

