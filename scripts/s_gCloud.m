%% Small test script to evaluate whether we got the cloud set up right
%
% ZL, BW

%%  Initialize

gcp = gCloud('dockerImage','gcr.io/primal-surfer-140120/pbrt-v2-spectral-gcloud',...
                'cloudBucket','gs://primal-surfer-140120.appspot.com');

% fName = fullfile('/','home','hblasins','City','001_city_1_placement_1_radiance.pbrt');
% workdir = fullfile('/','scratch','hblasins','pbrt2ISET','City');
% if exist(workdir,'dir') == false,
%     mkdir(workdir);
% end
% 
% scene = piRead(fName);
% scene.set('rays per pixel',32);
% 
% d = fileparts(fName);
% scene.set('outputFile',fullfile(workdir,'city.pbrt'));
% piWrite(scene);


gcp.upload(scene);
gcp.render();
gcp.download();