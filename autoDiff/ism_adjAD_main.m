function [vv2] = ism_adjLM_main(vv,rr ,aa,pp,gg,oo )
%% Shallow Stream Model 
% Inputs:
%   vv      struct containing initial solution variables
%   aa      prescribed fields, including inputs and boundary conditions
%   pp      parameters
%   gg      grid and operators
%   oo      options
% Outputs:
%   vv2     struct containing new solution variables

numIter = 10;                               %Number of Picard Iterations


if strcmp(oo.pT, 'forward'); C = aa.C; end; %Problem Type
if strcmp(oo.pT, 'inverse'); C = vv.C; end;

X = [gg.du_x gg.dv_y; gg.du_x -gg.dv_y; gg.dhu_y gg.dhv_x; speye(gg.nua,gg.nua) sparse(gg.nua,gg.nva); sparse(gg.nva,gg.nua) speye(gg.nva,gg.nva)];
X2 = [gg.dh_x gg.dh_x gg.duh_y speye(gg.nua,gg.nua) sparse(gg.nva,gg.nua)'; gg.dh_y -gg.dh_y gg.dvh_x sparse(gg.nua,gg.nva)' speye(gg.nva,gg.nva)];



firstpass = 1;

for j = numIter:-1:1
    

%% A matrix for current picard iteration 
A_r = rr.An{j};
U = rr.Un(:,j); U_r = U;
b = zeros(numel(U),1);

if ~firstpass
    %adjU = ism_visc_AD(z,U,nEff(:),C(:),aa,pp,gg,oo)  adjnEff
    
else
    adjU = rr.adjU.dU; adjU_r = adjU;
    firstpass = 0;
end

%% Handle BC for A matrix and Velocity Array 

if any(gg.nperbc)

tmp_a = [gg.S_u*(gg.nperbc_ugrid(:) < 0); gg.S_v*(gg.nperbc_vgrid(:) < 0)]; tmp_a = logical(tmp_a);
tmp_b = [gg.S_u*(gg.nperbc_ugrid(:) > 0); gg.S_v*(gg.nperbc_vgrid(:) > 0)]; tmp_b = logical(tmp_b); 
tmp_c = tmp_a | tmp_b;

U_r(tmp_c) = [];
adjU_r(tmp_c) = [];
A_r(:,tmp_c) = [];
A_r(tmp_c,:) = [];

clear tmp_a tmp_b tmp_c;
end

%% Intermediate step to determining the adjoint of A matrix
b_r = A_r'\adjU_r;

%% Apply BC to b array

if any(gg.nperbc)

tmp_a = [gg.S_u*(gg.nperbc_ugrid(:) < 0); gg.S_v*(gg.nperbc_vgrid(:) < 0)]; tmp_a = logical(tmp_a);
tmp_b = [gg.S_u*(gg.nperbc_ugrid(:) > 0); gg.S_v*(gg.nperbc_vgrid(:) > 0)]; tmp_b = logical(tmp_b); 
tmp_c = tmp_a | tmp_b;

b(~tmp_c) = b_r;
clear tmp_a tmp_b tmp_c;
end   
  
%% Determine adjoint of A matrix
adjA = -b*U';   

clear b;

%% Determine adjoint of Viscosity                                   
nEffholder = inf([gg.nha,1]);                                       %Calculate Viscosity
nEff = ism_visc(gg.S_h*aa.s(:),U,nEffholder,C(:),aa,pp,gg,oo);

nEff_adi = struct('f', nEff, 'dnEff',ones(gg.nha,1));   %Calculate main diagonal of D matrix (A = X2*D*X)
nEffAD = ism_dim_Ddiag_ADnEff(C(:),nEff_adi,aa,pp,gg,oo);
nEff_Ddiag = sparse(nEffAD.dnEff_location(:,1),nEffAD.dnEff_location(:,2), nEffAD.dnEff, nEffAD.dnEff_size(1), nEffAD.dnEff_size(2));

tic
for i = 1:gg.nha
tmp = X2*spdiags(nEff_Ddiag(:,i),0,nEffAD.dnEff_size(1),nEffAD.dnEff_size(1))*X;
adjnEff(i) = tmp(:)'*adjA(:);
end
toc

clear nEff_adi nEffAD nEff_Ddiag tmp;

%% Determine adjoint of Basal SLip
C_adi = struct('f', C(:), 'dC',ones(gg.nha,1));   %Calculate main diagonal of D matrix (A = X2*D*X)
CAD = ism_dim_Ddiag_ADc(C_adi,nEff(:),aa,pp,gg,oo);
C_Ddiag = sparse(CAD.dC_location(:,1),CAD.dC_location(:,2), CAD.dC, CAD.dC_size(1), CAD.dC_size(2));

tic
for i = 1:gg.nha
tmp = X2*spdiags(C_Ddiag(:,i),0,CAD.dC_size(1),CAD.dC_size(1))*X;
adjC(i) = tmp(:)'*adjA(:);
end
toc

clear C_adi CAD C_Ddiag tmp;


end




end

