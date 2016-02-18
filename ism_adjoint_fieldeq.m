function [LHS, RHS] = ism_adjoint_fieldeq(vv,aa,pp,gg,oo)
%% Field Equations for Adjoint  
% Inputs:
%   u,v     velocities in the x,y directions
%   aa      prescribed fields, including inputs and boundary conditions
%   pp      parameters
%   gg      grid and operators
%   oo      options
% Outputs: Ax = b
%   LHS     Left hand side. 
%   RHS     Right hand side.

n = pp.n_Glen;                          

%% Variables (Non-Dimensionalized)
nha = sum(gg.S_h(:));                               %number of active h-grid nodes
nua = sum(gg.S_u(:));
nva = sum(gg.S_v(:));
h_diag = spdiags(gg.S_h*aa.h(:),0,nha,nha);         %Diagonalize     
Cslip_diag = spdiags(gg.S_h*vv.C(:),0,nha,nha);        

[Sx,Sy] = gradient(aa.s, gg.dx, gg.dy); %Use gradient instead of gg.nddx/y since periodic BC conditions do not apply      
Sx = Sx(:); Sy = -Sy(:); 


exx = gg.du_x*vv.u;                                %Strain Rates
eyy = gg.dv_y*vv.v;
exy = 0.5*(gg.dhu_y*vv.u + gg.dhv_x*vv.v);
edeff = sqrt(exx.^2 + eyy.^2 + exx.*eyy + exy.^2 + pp.n_rp.^2);

nEff =  edeff.^((1-n)/n);                       %Effective Viscosity [dimensionless]
nEff_diag = spdiags(nEff(:),0,nha,nha);                                  


%% Field equations for lambda and mu
X = [gg.du_x gg.dv_y; gg.du_x -gg.dv_y; gg.dhu_y gg.dhv_x; gg.c_uh zeros(nha,nva); zeros(nha,nua) gg.c_vh];
X2 = [gg.dh_x gg.dh_x gg.duh_y gg.c_hu zeros(nha,nua)'; gg.dh_y -gg.dh_y gg.dvh_x zeros(nha,nva)' gg.c_hv];
D = blkdiag(3*pp.c6*nEff_diag*h_diag, pp.c6*nEff_diag*h_diag, pp.c6*nEff_diag*h_diag, Cslip_diag, Cslip_diag);

LHS = X2*D*X;

E1 = pp.c7*(aa.u - vv.u);                                %RHS Adjoint equations
E2 = pp.c7*(aa.v - vv.v);
RHS = [E1; E2];


end