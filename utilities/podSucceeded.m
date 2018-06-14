function cnt = podSucceeded(gcp)
% Count how many of the minimal kubernetes processes (PODS) have finished
%
%
% ZL/BW

cnt = 0;
result = gcp.Podslist();
for ii=1:length(result.items)
   if isequal(result.items(ii).status.phase,'Succeeded')
       cnt = cnt + 1;
   end
end
fprintf('Found %d PODS Succeeded\n',cnt);

end