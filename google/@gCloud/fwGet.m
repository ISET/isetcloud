function val = fwGet(gcp,param,varargin)
% Get a Flywheel parameter as part of the gCloud definitions
%
% Synopsis
%    val = gcp.fwGet(param,varargin)
%    val = fwGet(gcp,param,varargin);
%
% Inputs
%   gcp:    gCloud object
%   param:  String defining the parameter.  Options are
%        project id 
%        subject
%        session
%        acquisition
%        fw info
%        scene files id
%
% Optional key/value pairs
%   num     - Number of target in gcp.targets.  Default is 1.
%   scitran - Scitran object to connect with Flywheel
%
% Returns
%   val - The parameter value, or a struct of values (fwinfo)
%
% See also
%   gCloud, gCloud.fwSet
%

%% Examples:
%{
  val = gcp.fwGet('num',1,'projectid');
%}

%% Parse the inputs
varargin = stParamFormat(varargin);

p = inputParser;
p.addRequired('gcp',@(x)(isequal(class(x),'gCloud')));
p.addRequired('param',@ischar);
p.addParameter('num',1,@isinteger);
p.addParameter('scitran',[],@(x)(isequal(class(x),'scitran')));
p.parse(gcp,param,varargin{:});

% Either a specific target or all of them
num = p.Results.num;
if isempty(num), num = 1:numel(gcp.targets); 
elseif num < 1 || num > numel(gcp.targets)
    error('Bad num value %D.  There are %d targets',num,numel(gcp.targets));
end

st = p.Results.scitran;
%% Assign the value

switch stParamFormat(param)
    case 'fwinfo'
        val.projectID   = gcp.fwGet('projectid');
        val.session     = gcp.fwGet('session');
        val.subject     = gcp.fwGet('subject');
        val.acquisition = gcp.fwGet('acquisition');
    case 'projectid'
        val = gcp.targets(num).fwAPI.projectID;
    case 'subject'
        val = gcp.targets(num).fwAPI.subjectLabel;
    case 'session'
        val = gcp.targets(num).fwAPI.sessionLabel;
    case 'acquisition'
        val = gcp.targets(num).fwAPI.acquisitionLabel;
    case 'scenefilesid'
        % Before the days when files had a label/name?
        val = gcp.targets(num).fwAPI.sceneFilesID;
    case 'acquisitioncontainer'
        if isempty(st), error('scitran object required'); end
        
        fw = gcp.fwGet('fwinfo');
        project = st.fw.get(fw.projectID);
        acqString = sprintf('%s/%s/%s/%s/%s',...
            project.group,project.label,...
            fw.subject,fw.session,fw.acquisition');
        val = st.lookup(acqString);

    otherwise
        error('Unknown fwGet parameter %s\n',varargin{ii});
end

end
