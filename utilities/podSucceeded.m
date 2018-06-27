function [cnt,result,podnames] = podSucceeded(obj,varargin)
% Count how many of the kubernetes (PODS) have finished
%
% Syntax
%   [cnt, result, podnames] = podSucceeded(obj)
%
% Description
%    This routine counts how many PODS have Succeeded.  The routine is
%    used in a loop to wait for completion of all the jobs. In some
%    cases, there are 0 PODS and thus 0 Succeeded.  I suppose this
%    happens because the job is removed before we see the 'Succeeded'
%    string.  In that case we should return something helpful, not 0.
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
[podnames,result] = obj.Podslist('print',false);
nPODS = length(result.items);
if nPODS == 0
    % This is the case in which we lost our PODS.  We should do
    % something better.  But this solves one case.  A deeper solution
    % is needed. (BW).
    cnt = cnt + 1;
else
    for ii=1:nPODS
        if p.Results.print
            fprintf('%s\n',result.items(ii).status.phase);
        end
        if isequal(result.items(ii).status.phase,'Succeeded')
            cnt = cnt + 1;
        end
    end
end

if p.Results.print
    fprintf('Found %d PODS. N Succeeded = %d\n',nPODS,cnt);
    fprintf('------------\n');
end

end
