function [cnt,result] = podSucceeded(obj,varargin)
% Count how many of the kubernetes (PODS) have finished
%
% Syntax
%   [cnt, result] = podSucceeded(obj)
%
% Description
%    We set up processes to run in the cluster. This routine counts how
%    many processes have Succeeded.  The routine is used in a loop to wait
%    for completion of all the jobs
%
% Inputs
%   obj:  A gCloud object
%
% Key/value options
%   'print'  - Printout a summary if true
%
% Returns
%   cnt     - Number of PODS that indicate a status of 'Success'
%   results - Return from Podslist commands
%
% The code might be used like this
%
%  cnt = 0;
%  while cnt < length(gcp.targets)
%    cnt = podSucceeded(gcp);
%    pause(5);
%  end
%
% ZL/BW, Vistasoft team, 2018
%
% See also:  gCloud, gCloud.render, s_mcRenderMaterial

%%
p = inputParser;
p.addRequired('obj',@(x)(isa(x,'gCloud')));
p.addParameter('print',true,@islogical);
p.parse(obj,varargin{:});

%%
cnt = 0;
result = obj.Podslist('print',false);
nPODS = length(result.items);
for ii=1:nPODS
    if p.Results.print
        fprintf('%s\n',result.items(ii).status.phase);
    end
    if isequal(result.items(ii).status.phase,'Succeeded')
        cnt = cnt + 1;
    end
end

if p.Results.print
    fprintf('Found %d PODS. N Succeeded = %d\n',nPODS,cnt); 
    fprintf('------------\n');
end

end
