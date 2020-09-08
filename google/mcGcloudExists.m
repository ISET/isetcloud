function [gcloudExists, status, result] = mcGcloudExists
%% check whether we have google cloud sdk in our path

% Windows doesn't have a which command.
% Many versions have a where command, though, so we can try to use it.
if ~ispc
    [status_gcloud, result.gcloud] = system('which gcloud');
    [status_gsutil, result.gsutil] = system('which gsutil');
    [status, result.kubectl] = system('which kubectl');
else
    [status_gcloud, result.gcloud] = system('where gcloud');
    [status_gsutil, result.gsutil] = system('where gsutil');
    [status, result.kubectl] = system('where kubectl');
end

gcloudExists = (0 == status==status_gcloud==status_gsutil);

end