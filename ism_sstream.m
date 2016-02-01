function [vv2] = ism_sstream(vv,aa,pp,gg,oo )
%% Shallow Stream Model 
% Inputs:
%   vv      struct containing initial solution variables
%   aa      prescribed fields, including inputs and boundary conditions
%   pp      parameters
%   gg      grid and operators
%   oo      options
% Outputs:
%   vv2     struct containing new solution variables
%   J       Jacobian matrix

numIter = 10;                               %Solver parameters
sstream_norm = zeros(numIter,1);

n = pp.n_Glen;                              %Ice Flow parameters 
if strcmp(oo.pT, 'forward'); C = aa.C; end
if strcmp(oo.pT, 'inverse'); C = vv.C; end

u = vv.u;                                   %Initial iterate velocity 
v = vv.v;

%% Remap indices [from whole region, to masked area]

A = sum(gg.S_u); A2 = cumsum(A);            %U-grid
nfxd_uind = A2(gg.nfxd_uind);               %Fixed nodes                   
nperbc_u1ind  = A2(gg.nperbc_u1ind);           %Periodic BC nodes
nperbc_u2ind  = A2(gg.nperbc_u2ind);
vOff = sum(A);                              %offset to v values [number of u values]

A = sum(gg.S_v); A2 = cumsum(A);            %V-grid
nfxd_vind = A2(gg.nfxd_vind) + vOff;        %Fixed nodes   
nperbc_v1ind = A2(gg.nperbc_v1ind) + vOff;  %Periodic BC nodes
nperbc_v2ind = A2(gg.nperbc_v2ind) + vOff;

%Periodic BC Nodes



%% Picard Iterations
for j = 1:numIter

    [LHS, RHS] = ism_sstream_fieldeq(u,v,C,aa,pp,gg,oo);      %Field Equations
    U = Inf(size(LHS,2),1);                   %Unmodified velocity vector    
    
    %% Boundary Conditions
    
    %Apply BC
    DEL = [];
    if any(gg.nfxd(:))
    RHS = RHS - LHS(:,nfxd_uind)*aa.nfxd_uval;
    RHS = RHS - LHS(:,nfxd_vind)*aa.nfxd_vval;    
    DEL = union(nfxd_uind, nfxd_vind);
    end
    
    if any(gg.nperbc(:))
    LHS(:, nperbc_u1ind) = LHS(:, nperbc_u1ind) + LHS(:, nperbc_u2ind); % Apply Periodic BC
    LHS(:, nperbc_v1ind) = LHS(:, nperbc_v1ind) + LHS(:, nperbc_v2ind); 
    DEL = union(DEL, [nperbc_u2ind; nperbc_v2ind]);
    end

    LHS(:,DEL) = [];
    
    %Solve 
    Um = LHS\RHS;               %Solve modified field equations
    
    %Return to original velocity vector
    U(DEL) = NaN;
    U(~isnan(U)) = Um;
    
    if any(gg.nfxd(:))
        U(nfxd_uind) = aa.nfxd_uval;
        U(nfxd_vind) = aa.nfxd_vval;
    end
    
    if any(gg.nperbc)
        U(nperbc_u2ind) = U(nperbc_u1ind);
        U(nperbc_v2ind) = U(nperbc_v1ind);
    end
    
    u = U(1:vOff);    %u,v velocity fields
    v = U(vOff+1:end);
    
    sstream_norm(j) = norm(RHS-LHS*Um,oo.norm); %iteration norm (using Um)
    
end

vv.u = u;
vv.v = v;
vv.sstream_norm = sstream_norm;

vv2=vv;

end



