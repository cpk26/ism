
function [cst,gradN] = ism_adjAD_optWrapper(acoeff,vv,aa, pp, gg, oo)
% Inputs:
%   vv      struct containing initial solution variables
%   aa      prescribed fields, including inputs and boundary conditions
%   pp      parameters
%   gg      grid and operators
%   oo      options
% Outputs:
%   vv2     updated struct with new alpha coefficients

%Set flag to save intermediate steps in Picard Iteration if we are
%calculating the gradient during this function call
if nargout > 1; oo.savePicIter = 1; else oo.savePicIter = 0; end

vv.acoeff = reshape(acoeff,gg.nJ,gg.nI);   %Array=>matrix
vv.C = ism_cslip_field(vv, pp, gg, oo);    %reconstruct basal slipperiness

[vv] = ism_sia(aa.s,aa.h,vv.C,vv, pp,gg,oo);    %SIA                                        
[vv, rr] = ism_deism(vv,aa,pp,gg,oo );          %SSA 

F1 = ism_falpha(1,vv,aa,pp,gg,oo );          %Calculate F alpha factors 
F2 = ism_falpha(2,vv,aa,pp,gg,oo );

cst = ism_inv_cost(vv.U,vv.C,F1,F2,vv,aa,pp,gg, oo);  %Current misfit

if nargout > 1 % gradient required
    
    %Call ism_AD_inv_Cst
    U_adi = struct('f', vv.U, 'dU',ones(gg.nua+gg.nva,1));
    UAD = ism_inv_cost_ADu(U_adi,vv.C,F1,F2,vv,aa,pp,gg,oo);
    rr.adjU = UAD.dU;
    
    %imagesc(reshape(rr.adjU(1:gg.nua),75,76))
    if oo.hybrid
    C_adi = struct('f', vv.C(:), 'dC',ones(gg.nha,1));
    UAC = ism_inv_cost_ADc(vv.U,C_adi,F1,F2,vv,aa,pp,gg,oo);
    rr.adjC = UAC.dC;
    end
    %imagesc(reshape(rr.adjC,75,75))
    rr = ism_adjAD_main(vv,rr,aa,pp,gg,oo );
    
    grad = rr.runC.*exp(vv.acoeff(:));
    gradN = grad./max(abs(grad));
end

end   

