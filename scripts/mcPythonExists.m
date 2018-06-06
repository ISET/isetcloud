function val = mcPythonExists
% Tests whether python exists on user's path
% 
% ZL Vistasoft Team, 2018

% Check whether we have a python
[~,output] = system('which python');

% Remove the <CR> at the end of the output
[p,n] = fileparts(output(1:(end-1)));

if strcmp(n,'python')
    % Set up the python environment variables within the Matlab
    % framework.  These are not necessarily inherited if you click to
    % start Matlab, rather than start Matlab from the command line.
    fprintf('Found python in %s\n',p);
    val = true;
else
    fprintf('No python executable found.  Suggest checking installation');
    val = false;
end

end