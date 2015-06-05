function [xGr,yGr] = wellsGrid(grOld,well,dmax,dmin,nstp)
% [xGr,yGr] = gridObj.wellsGrid(well,dmax,dmin,nstep) -- generates a grid
% suitable for wells starting with the grid implied in gridObj
%
% a subgrid is gnerated around each well using log10 distances from dminto
% dmax in nstp. The center subcell has dimension dmin*dmin
%

% to prevent too small grid spaces with multiple wells, put all wells
% at center of dmin
for iw = 1:length(well)
    well(iw).x = round(well(iw).x/dmin)*dmin;
    well(iw).y = round(well(iw).y/dmin)*dmin;
end

dSub = logspace(log10(dmin),log10(dmax),nstp);

Sub = cumsum([ dSub(1)/2 dSub(2:end)]);
Sub = [-Sub(end:-1:1) Sub(1:end-1)];
dSub = diff(Sub);
mSub = 0.5*(Sub(1:end-1)+Sub(2:end));

ns = length(Sub);

xGr = [grOld.xGr(:)', NaN(1,length(well)*length(Sub))];
yGr = [grOld.yGr(:)', NaN(1,length(well)*length(Sub))];
for iw=1:length(well)
    xGr(grOld.Nx+1 + (iw-1)*ns + (1:ns)) = well(iw).x + Sub;
    yGr(grOld.Ny+1 + (iw-1)*ns + (1:ns)) = well(iw).y + Sub;
end

xGrInt = unique(xGr);
yGrInt = unique(yGr);

xmInt  = 0.5*(xGrInt(1:end-1)+xGrInt(2:end));
ymInt  = 0.5*(yGrInt(1:end-1)+yGrInt(2:end));

dxMax = dmax * ones(size(xmInt));
dyMax = dmax * ones(size(ymInt));

NxInt   = length(xGrInt);
NyInt   = length(yGrInt);

Nxm     = length(xmInt);
Nym     = length(ymInt);

for iw = 1:length(well)
    Ifrx = min(floor(interp1(xGrInt,1:NxInt,well(iw).x+mSub)),Nxm);
    Ifry = min(floor(interp1(yGrInt,1:NyInt,well(iw).y+mSub)),Nym);

    Ix = find(~isnan(Ifrx));
    Iy = find(~isnan(Ifry));
    
    dxMax(Ifrx(Ix)) = min([dxMax(Ifrx(Ix));dSub(Ix)]);
    dyMax(Ifry(Iy)) = min([dyMax(Ifry(Iy));dSub(Iy)]);
end

%%
% use xGr and yGr and not gridObj because this only affects the plane not
% the Z.
xGr = cleanGrid(xGrInt,dxMax,dmin);
yGr = cleanGrid(yGrInt,dyMax,dmin);


function xGr=cleanGrid(xGr,dxMax,dmin)

dx = diff(xGr);

for i = length(dxMax)-1:-1:1
    if dxMax(i)>dx(i) && dxMax(i+1)>dx(i+1) && dx(i)+dx(i+1) < min(dxMax(i:i+1))
        xGr(i+1)=[];
        dx(i  ) = sum(dx(i:i+1));
        dx(i+1) = [];
        dxMax(i)=min(dxMax(i:i+1));
        dxMax(i)=[];
    end
end

for i = length(dxMax)-1:-1:1
    if  dx(i)<dmin,
        xGr(i+1)=[];
        dx(i  ) = sum(dx(i:i+1));
        dx(i+1) = [];
        dxMax(i)=min(dxMax(i:i+1));
        dxMax(i)=[];
    end
end

