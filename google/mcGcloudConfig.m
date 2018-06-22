function mcGcloudConfig
% Configure the Matlab kubernetes and gsutil functions
%
%
% ZL Vistasoft Team, 2018

%% Configure Matlab ENV for google SDK 

% Check that the user has kubectl on their path.
[status, kubePath] = system('which kubectl');
kubePath = kubePath(1:(end-1));

if status
    fprintf('Could not find kubectl on your path.  Please install.\n');
    return;
else
    % kubectl was found.  So we figure out the path and make sure the
    % Matlab environment includes that path.
    fprintf('Found kubectl at %s\n',kubePath');
    
    initPath = getenv('PATH');

    kubePath = fileparts(kubePath);
    fprintf('Adding %s to PATH.\n',kubePath);
    setenv('PATH', [kubePath,':',initPath]);
    
    %% Configure google SDK
    gcloudPath = fullfile(fileparts(kubePath),'path.bash.inc');
    cmd = sprintf('source %s',gcloudPath);
    status = system(cmd);
    if status, error('Failed to run path.bash.inc'); end
    
    [status, gsutilPath] = system('which gsutil');
    if status, error('Failed to find gsutil'); end
    fprintf('Found gsutil at %s\n',gsutilPath(1:(end-1))');
end

end
