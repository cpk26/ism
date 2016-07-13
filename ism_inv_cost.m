function [ cst ] = ism_inv_cost(U,C,F1,F2,vv,aa,pp,gg, oo)
%% Inversion cost function
% Inputs:
%   vv      struct containing initial solution variables
%   aa      prescribed fields, including inputs and boundary conditions
%   oo      options
% Outputs:
%   cst     Inversion cost


u = U(1:gg.nua); 
v = U(gg.nua+1:end);

if oo.hybrid                                      %Hybrid Model; Compute surface velocities
Cb = C;
tmpa = (1 + Cb(:).*F1)./(1 + Cb(:).*F2);          %U_eff to U_surface factor on h-grid
tmpa_u = (gg.c_hu*tmpa)./(gg.c_hu*(gg.S_h*gg.m(:) ==2));    %Interpolate onto u/v grids
tmpa_v = (gg.c_hv*tmpa)./(gg.c_hv*(gg.S_h*gg.m(:) ==2));    %Extrapolate at edges

if any(gg.nmgn(:))                                  %Ice Margin Nodes
tmpa_u(gg.nmgn_ugrid) = 1;                          %No vertical variation in velocity at ice margin                                       
tmpa_v(gg.nmgn_vgrid) = 1;
end

u = u.*tmpa_u;                                      %Surface velocities                    
v = v.*tmpa_v;                    
end

%Velocity Misfit
if strcmp(oo.inv_cst,'abs') 
    cu = gg.c_uh*(u-aa.u).^2;
    cv = gg.c_vh*(v-aa.v).^2;   
    cst = pp.c9*0.5*sum( cu + cv )*gg.dx*gg.dy;
elseif strcmp(oo.inv_cst,'rel') 
    cu = gg.c_uh*min( ((u-aa.u)./aa.u).^2,1);
    cv = gg.c_vh*min( ((v-aa.v)./aa.v).^2,1);
    cst = pp.c10*0.5*sum( cu + cv )*gg.dx*gg.dy; 
elseif strcmp(oo.inv_cst,'log') 
    vn = (10/pp.ty)/pp.u;               %Velocity normalization 
    cm = sqrt( (gg.c_uh*u).^2 + (gg.c_vh*v).^2 ) + vn;
    co = sqrt( (gg.c_uh*aa.u).^2 + (gg.c_vh*aa.v).^2 ) + vn;
    cst = sum( (log(cm./co)).^2 );
    
end

cst = pp.L_vel*cst;

%Add Cost function enforcing smoothness for 'grid' discretization: I think
%this is wrong. Havent used in a while, need to reevaluate.
if strcmp(oo.Cdisc,'grid') && ~isequal(pp.L_smooth,0)
C1 = (1/pp.x)*gg.dh_x*gg.S_h*vv.acoeff(:).*((gg.c_hu*gg.S_h*ones(gg.nIJ,1)) == 1); %gradient of alpha coefficients, x,y directions
C2 = (1/pp.x)*gg.dh_y*gg.S_h*vv.acoeff(:).*((gg.c_hv*gg.S_h*ones(gg.nIJ,1)) == 1); %ignoring values on boundary nodes
tik = 0.5*pp.c10*(sum(C1(:).^2) + sum(C2(:).^2))*gg.dx*gg.dy;
cst = cst + pp.L_smooth*tik;
end


end

