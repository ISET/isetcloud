function rootPath = mcRootPath()
% Return the path to the root matlab2cloud directory
%
% This function must reside in the directory at the base of the
% matlab2cloud directory structure.  It is used to determine the
% location of various sub-directories.
% 
% Example:
%   fullfile(mcRootPath,'scripts')
%
% ZL,BW

rootPath = fileparts(which('mcRootPath'));

end
