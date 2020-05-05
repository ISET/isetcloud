function obj = readTarget(obj,targetName)
% Copy the flywheel information from target.json file to gcp.fwAPI.
% Syntax
%   gcp = gcp.readTarget(targetName);
%
% Description
%   Parse a target.json file, copy the slots to a gcp object, so we can 
%   re-render a scene without writing out and uploading the file to
%   flywheel again.
%
% Input
%   targetName: Path to the target.json for the scene.
%
% Zhenyi,2020
%
%%

% This is the JSON file
scene_target = jsonread(targetName);

% I think these are all the slots we need
obj.targets.fwAPI  = scene_target.fwAPI;
obj.targets.remote = scene_target.remote;
obj.targets.local  = scene_target.local;


end