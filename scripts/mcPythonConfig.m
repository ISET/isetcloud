function mcPythonConfig
[~,output] = system('which python');
output = output(1:15);
if strcmp(output,'/usr/bin/python')
    initPath = getenv('PATH');
    PythonPath = '/Library/Frameworks/Python.framework/Versions/2.7/bin/';
    setenv('PATH', [PythonPath,':', initPath]);
end
% test it
[~,output] = system('which python');
fprintf('Change python to %s', output);
end