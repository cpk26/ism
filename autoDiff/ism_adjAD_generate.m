function [] = ism_adjAD_generate( vv,aa, pp, gg, oo )
%Automatically differentiate necessary functions using Adigator, specifying
%input sizes from current simulation

%% Clear working directory of previously generated AD function
fn = {'ism_inv_cost_ADu', 'ism_inv_cost_ADc','ism_visc_AD','ism_visc_diAD','ism_dim_Ddiag_ADc','ism_dim_Ddiag_ADnEff'};
for j = 1:numel(fn)
    tmpA = char(strcat(fn(j), '.m')); tmpB = char(strcat(fn(j), '.mat'));
    if exist(tmpA, 'file'), delete(tmpA); end; 
    if exist(tmpB, 'file'), delete(tmpB); end; 
end

%% Apply Automatic Differentiation

%Cost Function w.r.t velocity
U = adigatorCreateDerivInput([gg.nua+gg.nva,1], 'U');
C = adigatorCreateAuxInput([gg.nha,1]);
F1 = adigatorCreateAuxInput([gg.nha,1]);
F2 = adigatorCreateAuxInput([gg.nha,1]);
adigator('ism_inv_cost', {U,C,F1,F2,vv,aa,pp,gg,oo},'ism_inv_cost_ADu')
clear U C F1 F2;


%Cost Function w.r.t Basal Slipperiness
C = adigatorCreateDerivInput([gg.nha,1],'C');
U = adigatorCreateAuxInput([gg.nua+gg.nva,1]);
F1 = adigatorCreateAuxInput([gg.nha,1]);
F2 = adigatorCreateAuxInput([gg.nha,1]);
adigator('ism_inv_cost', {U,C,F1,F2,vv,aa,pp,gg,oo},'ism_inv_cost_ADc')
clear U C F1 F2;


%Viscosity w.r.t velocity
U = adigatorCreateDerivInput([gg.nua+gg.nva,1], 'U');
adigator('ism_visc', {U,vv,aa,pp,gg,oo},'ism_visc_AD')
clear U;

%Depth Integrated Viscosity w.r.t velocity
U = adigatorCreateDerivInput([gg.nua+gg.nva,1], 'U');
nEff = adigatorCreateAuxInput([gg.nha,1]);
C = adigatorCreateAuxInput([gg.nha,1]);
adigator('ism_visc_di', {U,nEff,C,aa,pp,gg,oo},'ism_visc_diAD')
clear z U nEff C;

%Diagonal of A matrix w.r.t Basal slipperiness
C = adigatorCreateDerivInput([gg.nha,1], 'C');
nEff = adigatorCreateAuxInput([gg.nha,1]);
adigator('ism_dim_Ddiag', {C,nEff,aa,pp,gg,oo},'ism_dim_Ddiag_ADc')
clear C nEff;

%Diagonal of A matrix w.r.t depth integrated viscosity
nEff = adigatorCreateDerivInput([gg.nha,1], 'nEff');
C = adigatorCreateAuxInput([gg.nha,1]);
adigator('ism_dim_Ddiag', {C,nEff,aa,pp,gg,oo},'ism_dim_Ddiag_ADnEff')
clear C nEff;



end

