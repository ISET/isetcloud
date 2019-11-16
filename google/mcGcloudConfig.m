function mcGcloudConfig
% Configure the Matlab PATH for the kubernetes and gsutil functions
%
% Syntax
%   mcGcloudConfig
%
% Description
%   Tries to figure out the paths to kubectl and gsutil and make sure
%   these are on the user's path
%
% ZL Vistasoft Team, 2018
%
% See also
%

%% Configure Matlab ENV for google SDK 

% Always put /usr/local/bin on the path
initPath = getenv('PATH');
if ~contains(initPath, '/usr/local/bin')
    if args.debug
        disp('Adding ''/usr/local/bin'' to PATH.');
    end
    setenv('PATH', ['/usr/local/bin:',initPath]);
end

% Check for kubectl.
[status, kubePath] = system('which kubectl');
if status
    % If it is not on the path, try this directory
    if exist('/usr/local/bin/google-cloud-sdk/bin','dir')
        disp('Adding ''/usr/local/bin/google-cloud-sdk/bin'' to PATH.');
        initPath = getenv('PATH');
        setenv('PATH', ['/usr/local/bin/google-cloud-sdk/bin:',initPath]);
    else
        error('Could not find kubectl directory.');
    end
    
    [status, kubePath] = system('which kubectl');
    if status, error('Could not find kubectl\n'); end
end

kubePath = kubePath(1:(end-1));

% kubectl was found.  So we figure out the path and make sure the
% Matlab environment includes that path.
fprintf('Found kubectl at %s\n',kubePath');

initPath = getenv('PATH');

kubePath = fileparts(kubePath);
if ~contains(initPath, kubePath)    
    fprintf('Adding %s to PATH.\n',kubePath);
    setenv('PATH', [kubePath,':',initPath]);
end
%% Configure google SDK

% This path.bash file is one level up from bin
gcloudPath = fullfile(fileparts(kubePath),'path.bash.inc');
cmd = sprintf('source %s',gcloudPath);
status = system(cmd);
if status
    warning('Failed to run path.bash.inc at %s',kubePath);
    gcloudPath = '/usr/local/bin/google-cloud-sdk';
    cmd = sprintf('source %s',fullfile(gcloudPath,'path.bash.inc'));
    status = system(cmd);
    if status
        error('Could not find path.bash.inc anywhere.');
    end
    
    % Add the gcloudPath
    gcloudPath = fullfile(gcloudPath,'bin');
    setenv('PATH', [gcloudPath,':',initPath]);
end

%%
[status, gsutilPath] = system('which gsutil');
if status, error('Failed to find gsutil'); end
fprintf('Found gsutil at %s\n',gsutilPath(1:(end-1))');


end
