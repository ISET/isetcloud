function gcp = targetDelete(gcp, val, varargin)
% Delete a PBRT target job from the google cloud engine instance
%
% Syntax
%    targetDelete(gcp,val, varargin);
%    gCloud.targetDelete)
%
% Description
%  We modify the gcp object to remove a rendering targets
%
% Inputs
%     gcp:  A gCloud object
%
% Returns
%   gcp:  This particular target, which has been placed in a slot
%
% ZL Vistateam, 2017
%   gCloud.targetsList, gCloud.addPBRTTarget
%   gCloud.targetsDelete

%% Parse
p = inputParser;

p.addRequired('gcp',@(x)(isequal(class(x,'gCloud'))));
p.addRequired('val',@isinteger);

p.parse(gcp,val,varargin{:});
val = p.Results.val;

%% Remove the target

% This code is not really tested
nTargets = length(gcp.targets);
if val > 0 && val <= nTargets
    lst = ones(nTargets,1);
    lst(val) = 0;
    lst = logical(lst);
    gcp.targets = gcp.targets(lst);
else
    error('val out of range (%d)',val);
end

end