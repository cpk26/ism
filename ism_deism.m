function [vv2, rr] = ism_deism(vv,aa,pp,gg,oo )
%% Shallow Stream Model 
% Inputs:
%   vv      struct containing initial solution variables
%   aa      prescribed fields, including inputs and boundary conditions
%   pp      parameters
%   gg      grid and operators
%   oo      options
% Outputs:
%   vv2     struct containing new solution variables

numIter = oo.pic_iter;                      %Solver parameters
sstream_norm = zeros(numIter,1);

if strcmp(oo.pT, 'forward'); C = aa.C; end; %Problem Type
if strcmp(oo.pT, 'inverse'); C = vv.C; end;

U = vv.U;                                   %Initial iterate velocity
u = vv.u;                                   
v = vv.v;

                                            %Ensure an initial viscosity
nEff = ism_visc(U,vv,aa,pp,gg,oo);          %SSA
if oo.hybrid,                               %Hybrid Approximation      
for j=[1:5], nEff = ism_visc_di(U,gg.S_h*nEff,C(:),aa,pp,gg,oo);end,end;


rr = struct();                              %Preallocate arrays if we are saving picard iterations
if isequal(oo.savePicIter,1)
    rr.An = cell(1,numIter); 
    rr.Un = zeros(gg.nua+gg.nva,numIter+1);
    rr.nEffn = zeros(gg.nha,numIter);
end

if isequal(oo.savePicIter,1),rr.Un(:,1) = U; end    %Save initial velocity                  

%% Picard Iterations
for j = 1:numIter

    
%Insert Test Code HEre

if oo.hybrid                            %Determine viscosity depending on approximation
nEff = ism_visc_di(U,gg.S_h*nEff,C(:),aa,pp,gg,oo);       
else nEff = ism_visc(U,vv,aa,pp,gg,oo); end           %SSA Viscosity

[LHS, RHS] = ism_deism_fieldeq(C,nEff, aa,pp,gg,oo);              %Field Equations
U = Inf(size(LHS,2),1);                                                 %Velocity vector, full length   

if isequal(oo.savePicIter,1),rr.An{j} = LHS; end                        %Save
if isequal(oo.savePicIter,1),rr.nEffn(:,j) = nEff(:); end                        

%% Apply Boundary Conditions

DEL = zeros(gg.nua+gg.nva,1);                   %Columns to delete
DEL2 = DEL;                                     %Rows to delete

if any(gg.nmgn(:))  %Ice Margin Nodes
hu = (gg.c_hu*gg.S_h*aa.h(:))./(gg.c_hu*gg.S_h*(aa.h(:) > 0));            %Thickness on u,v grids, linear extrapolation at the edges
hv = (gg.c_hv*gg.S_h*aa.h(:))./(gg.c_hv*gg.S_h*(aa.h(:) > 0));

t_mgn = [0.5*pp.c4*(0.5*hu).^2; 0.5*pp.c4*(0.5*hv).^2];                   %Boundary Condition at Ice Margin
mgn_mask = [gg.S_u*gg.nmgn_ugrid(:); gg.S_v*gg.nmgn_vgrid(:)];            %Ice Margin Node Mask

RHS(logical(mgn_mask)) = 0;                                               %Insert Ice Margin BC
RHS = RHS + mgn_mask.*t_mgn;
end

if any(gg.nfxd(:))  %Dirichlet BC Nodes
tmp_a = [gg.S_u*aa.nfxd_uval(:); gg.S_v*aa.nfxd_vval(:)];                 %Vector of fixed values
tmp_b = [gg.S_u*gg.nfxd_ugrid(:); gg.S_v*gg.nfxd_vgrid(:)];               %Location of fixed values

RHS = RHS - LHS*tmp_a;
DEL = DEL + tmp_b;
DEL2 = DEL2 + DEL;

clear tmp_a tmp_b;
end

if any(gg.nperbc(:))    %Periodic BC nodes
    
tmp_a = [gg.S_u*(gg.nperbc_ugrid(:) < 0); gg.S_v*(gg.nperbc_vgrid(:) < 0)]; tmp_a = logical(tmp_a);
tmp_b = [gg.S_u*(gg.nperbc_ugrid(:) > 0); gg.S_v*(gg.nperbc_vgrid(:) > 0)]; tmp_b = logical(tmp_b); 

LHS(:, tmp_b) = LHS(:, tmp_b) + LHS(:, tmp_a);

DEL = DEL + [tmp_a];
DEL2 = DEL2 + [tmp_a];

clear tmp_a tmp_b tmp_c tmp_d

end

DEL = logical(DEL);
DEL2 = logical(DEL2);

LHS(:,DEL) = [];
LHS(DEL2,:) = [];
RHS(DEL2,:) = [];

%Solve 
Um = LHS\RHS;               %Solve modified field equations

%Return to original velocity vector
U(DEL) = NaN;
U(~isnan(U)) = Um;

if any(gg.nfxd(:))
tmp_a = [gg.S_u*gg.nfxd_ugrid(:); gg.S_v*gg.nfxd_vgrid(:)]; tmp_a = logical(tmp_a);
tmp_b = [gg.S_u*aa.nfxd_uval(:); gg.S_v*aa.nfxd_vval(:)];              

U(tmp_a) = tmp_b(tmp_a);
clear tmp_a tmp_b;
end

if any(gg.nperbc)

tmp_a = [gg.S_u*(gg.nperbc_ugrid(:) < 0); gg.S_v*(gg.nperbc_vgrid(:) < 0)]; tmp_a = logical(tmp_a);
tmp_b = [gg.S_u*(gg.nperbc_ugrid(:) > 0); gg.S_v*(gg.nperbc_vgrid(:) > 0)]; tmp_b = logical(tmp_b); 

U(tmp_a) = U(tmp_b);

clear tmp_a tmp_b;
end

u = U(1:gg.nua);    %u,v velocity fields
v = U(gg.nua+1:end);

sstream_norm(j) = norm(RHS-LHS*Um,oo.norm); %iteration norm (using Um)


if isequal(oo.savePicIter,1),rr.Un(:,j+1) = U; end                %Save Intermediate velocity array

end

vv.U = U;
vv.u = u;
vv.v = v;
vv.nEff = nEff;
vv.sstream_norm = sstream_norm;

vv2=vv;

end


%Test Code
% U1 = U;
% U2 = U; U2(1) = U2(1) + 1e-12;
% nEff1 = ism_visc_di(U1,gg.S_h*nEff,C(:),aa,pp,gg,oo);    
% nEff2 = ism_visc_di(U2,gg.S_h*nEff,C(:),aa,pp,gg,oo);    
% d = (nEff2(1) - nEff1(1)) / 1e-12;
% 
% 
% U_adi = struct('f', U, 'dU',ones(gg.nua+gg.nva,1)); 
% UAD = ism_visc_diAD(U_adi,gg.S_h*nEff,C(:),aa,pp,gg,oo);    
% U_visc = sparse(UAD.dU_location(:,1),UAD.dU_location(:,2), UAD.dU, UAD.dU_size(1), UAD.dU_size(2));
% 
% adjnEff = ones(75*75,1);
% adjU = U_visc'*adjnEff;
% aa = reshape(adjU(1:gg.nua),75,76);
% imagesc(aa);
% colorbar();
% caxis([-.1,.1]);
% figure
% 
% 
% UAD = ism_visc_AD(U_adi,vv,aa,pp,gg,oo);    
% U_visc = sparse(UAD.dU_location(:,1),UAD.dU_location(:,2), UAD.dU, UAD.dU_size(1), UAD.dU_size(2));
% 
% adjnEff = ones(75*75,1);
% adjU = U_visc'*adjnEff;
% aa1 = reshape(adjU(1:gg.nua),75,76);
% imagesc(aa);
% colorbar();
% caxis([-.1,.1]);
% 
% figure;
% imagesc(aa-aa1);



