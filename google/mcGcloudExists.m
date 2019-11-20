function [gcloudExists, status, result] = mcGcloudExists
%% check whether we have google cloud sdk in our path

[status_gcloud, result.gcloud] = system('which gcloud');
[status_gsutil, result.gsutil] = system('which gsutil');
[status, result.kubectl] = system('which kubectl');

gcloudExists = (0 == status==status_gcloud==status_gsutil);

end