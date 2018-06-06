function mcPythonConfig
% Set up the environment to run a particular version of python
% 
% Assumption is we are running on a Mac with python in /usr/bin and
% the /Library/... path in place.
%
% ZL Vistasoft Team, 2018

% Check whether we have a python
[~,output] = system('which python');

output = output(1:15);
if strcmp(output,'/usr/bin/python')
    % Set up the python environment variables within the Matlab
    % framework.  These are not necessarily inherited if you click to
    % start Matlab, rather than start Matlab from the command line.
    initPath = getenv('PATH');
    PythonPath = '/Library/Frameworks/Python.framework/Versions/2.7/bin/';
    setenv('PATH', [PythonPath,':', initPath]);
else
    error('No python executable found.  Suggest checking installation');
end

% test it
[~,output] = system('which python');
fprintf('Found python in %s\n', output);

end