function mcGcloudConfig
%Configure the Matlab kubernetes and gsutil functions



%% Configure Matlab ENV for google SDK 
initPath = getenv('PATH');

% Status is 0 if we find it.
[status, kubePath] = system('which kubectl');

if status
    %We expect kubectl to be in this directory.  It would clever to
    %allow them to put it wherever they want, but we're not that
    %clever.
    kubePath = fullfile('/usr/local/bin/google-cloud-sdk/bin');
    if exist(fullfile(kubePath,'kubectl'),'file')
        fprintf('Adding %s to PATH.\n',kubePath);
        setenv('PATH', [kubePath,':',initPath]);
    else
        fprintf('Could not find kubectl on your system.\n');
        return;
    end
else
    fprintf('Found kubectl at %s\n',kubePath');
end

%% Configure google SDK
gcloudPath = fullfile('/usr/local/bin/google-cloud-sdk','path.bash.inc');
cmd = sprintf('source %s',gcloudPath);
status = system(cmd);
if status, error('Failed to run path.bash.inc'); end

[status, gsutilPath] = system('which gsutil');
if status, error('Failed to find gsutil'); end 
fprintf('Found gsutil at %s\n',gsutilPath');
end
