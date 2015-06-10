%% Example see USGS modpath Version 6 (2012)
%% SIMULATION5: backward multiple release time endpoint simulation (see manual p47ff)

path(path,fileparts(pwd))

%% The particles are released around the well at a number of time and traced back
%  till the beginning of the simulation. mf_analyze shows the position of
%  the particles released at different times.

% TO 130221

%% make sure path is set to parent directory
d=dir('..');
if ~strmatchi('mf_adaptALL.m',{d.name})
    error('%s: Can''t find file %s in the parent directory,\n%s\n',...
        mfilename,'mf_adaptALL.m',fileparts(pwd));
else        
    mf_adaptALL;
end

%% Modpath info pertaining to this simulation

%%
% Specify the number and placement of the starting points with each cell.

zone= 2; % as defined in ZONE see mf_adaptALL.m

%%
% Geerate the mpath_partileGroupObj from which MODPATH can generate the
% staring locations of the particles.
% Use a empty zone array
pGrp = mpath_particleGroupObj(gr,ismember(ZONE,zone),'name',basename,'IFace',[1 2 3 4 5],'placement',10,'LineSpec','bo');

%% Particles
% The definition above will allow to generate input for MODPATH from which
% MODPATH can generate the required starting points. So mfLab does not need
% to do that. To allow plotting the particles within mfLab, they can also
% be generated by mfLab using the method getParticles. This methods addes
% the particles to the mpath_particleGroupObj
pGrp   = pGrp.getParticles(gr);

%% Show particles in 3D

figure; hold on; view(3); xlabel('x [m]'); ylabel('y [m]'); zlabel('z [m]');

gr.plotMesh('faceAlpha',0.15);

pGrp.plot(); title('Particles starting points');

%% You can turn the graphic by hand to better view the particles

dummy = NaN;
save underneath  dummy