function fwSet(gcp,varargin)
% Set a Flywheel parameter as part of the gCloud definitions
%
% Synopsis
%    gcp.fwSet('variable',value,'variable2',value2 ...)
%
% Inputs
%   gcp:  The gCloud object
% 
% Optional key/value pairs
%   group - GCP doesn't seem to have a 'group' in the fwAPI slot.  Defaults to 'wandell' for now
%   project label - Project label, used for lookup.  ID is set.
%   project id - 
%   subject - label
%   session - label
%   acquisition -label
%   
% Returns
%   The gCloud object has fields that are adjusted for the Flywheel
%   information
%
% See also
%   gCloud
%

%%
varargin = stParamFormat(varargin);

p = inputParser;
p.addRequired('gcp',@(x)(isequal(class(x),'gCloud')));

p.addParameter('num',[],@isinteger);    % Target num
p.addParameter('projectid','',@ischar);
p.addParameter('projectlabel','',@ischar);
p.addParameter('subject','',@ischar);
p.addParameter('session','',@ischar);
p.addParameter('acquisition','',@ischar);

p.parse(gcp,varargin{:});

% Either a specific target or all of them
num = p.Results.num;
if isempty(num), num = 1:numel(gcp.targets); end

%% Assign each of the variables

for ii=1:2:numel(varargin)
    val = varargin{ii+1};
    switch varargin{ii}
        case 'projectid'
            gcp.targets(num).fwAPI.projectID = val;
        case 'subject'
            gcp.targets(num).fwAPI.subjectLabel = val;
        case 'session'
            gcp.targets(num).fwAPI.sessionLabel = val;
        case 'acquisition'
            gcp.targets(num).fwAPI.acquisitionLabel = val;
        case 'scenefilesID'
            % Before the days when files had a label/name?
            gcp.targets(num).fwAPI.sceneFilesID = val;
        otherwise
            error('Unknown fwSet parameter %s\n',varargin{ii});
    end
end

end
