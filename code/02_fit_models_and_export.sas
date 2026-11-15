/* Refit all 40 models to avoid stale or overwritten WORK results.
Exports retain full numeric precision. */
%macro precision_guard;
 %if "%upcase(%sysfunc(getoption(encoding)))" ne "UTF-8" and "%upcase(%sysfunc(getoption(encoding)))" ne "UTF8" %then %do;
  %put ERROR: Run this program in the verified UTF-8 SAS session.;
  %abort cancel;
 %end;
%mend;
%precision_guard;
options nodate nonumber;
proc datasets library=work nolist;
 delete audit_model_n audit_nobs adj_ls_all adj_diff_all;
quit;
libname recov "&OUTDIR" access=readonly;
ods html path="&OUTDIR" file="final_precision_results.html";
proc sql;
create table work.missing_audit as
select count(*) as N_total,
sum(EDU_PRINT='Missing') as N_edu,
sum(INCOME_PRINT='Missing') as N_income,
sum(EDU_PRINT='Missing' and INCOME_PRINT='Missing') as N_both,
sum(EDU_PRINT='Missing' or INCOME_PRINT='Missing') as N_either,
sum(EDU_PRINT ne 'Missing' and INCOME_PRINT ne 'Missing') as N_complete
from recov.pa4_main2014_v5;
quit;
proc print data=work.missing_audit noobs; run;
proc export data=work.missing_audit outfile="&OUTDIR/missing_audit.csv" dbms=csv replace; run;
%macro audit;
%do k=1 %to 4;
 %let outcome=%scan(Y_NEITHER Y_AERONLY Y_STRONLY Y_BOTH,&k);
 %do sex=1 %to 2;
  %let sx=%scan(Male Female,&sex);
  %do spec=1 %to 5;
   %let wt=WT_MAIN;
   %let extra=;
   %let filt=1;
   %let label=MAIN;
   %if &spec=2 %then %do; %let label=NOCOVID; %let filt=SURVEY_YEAR not in (2020,2021); %let wt=WT_NOCOVID; %end;
   %if &spec=3 %then %do; %let label=NO2014; %let filt=SURVEY_YEAR ne 2014; %let wt=WT_NO2014; %end;
   %if &spec=4 %then %do; %let label=BMICHRONIC; %let extra=BMI_CAT CHRONIC_CAT; %end;
   %if &spec=5 %then %let label=LEIS;
   data work.model_data;
    set recov.pa4_main2014_v5;
    where SEX_PRINT="&sx" and (&filt);
    WT_NO2014=MY_WT/9;
    %if &spec=5 %then %do;
     if LEIS_VIG_VALID ne 1 or LEIS_MOD_VALID ne 1 then delete;
     if missing(LEIS_VIG) or missing(LEIS_MOD) or missing(PA_STRENGTH_FREQ) then delete;
     LT_EQ=LEIS_MOD+2*LEIS_VIG;
     LT_AER=(LT_EQ>=150); LT_STR=(PA_STRENGTH_FREQ>=2);
     Y_NEITHER=(LT_AER=0 and LT_STR=0);
     Y_AERONLY=(LT_AER=1 and LT_STR=0);
     Y_STRONLY=(LT_AER=0 and LT_STR=1);
     Y_BOTH=(LT_AER=1 and LT_STR=1);
    %end;
   run;
   proc datasets library=work nolist; delete audit_nobs adj_ls adj_diff; quit;
   ods exclude all;
   ods output DataSummary=work.audit_nobs LSMeans=work.adj_ls Diffs=work.adj_diff;
   proc surveyreg data=work.model_data;
    strata UNIFIED_STRATA;
    cluster UNIFIED_PSU;
    weight &wt;
    class AGE_PRINT EDU_PRINT INCOME_PRINT YEAR_PRINT &extra;
    model &outcome=AGE_PRINT EDU_PRINT INCOME_PRINT YEAR_PRINT &extra / solution;
    lsmeans AGE_PRINT EDU_PRINT INCOME_PRINT / om cl diff alpha=0.05;
   run;
   ods output close;
   ods exclude none;
   %if not %sysfunc(exist(work.audit_nobs)) %then %do;
    %put ERROR: Missing model summary for &label &sx &outcome.;
    %abort cancel;
   %end;
   data work.audit_nobs;
    length Spec $16 Sex $6 Outcome $12;
    set work.audit_nobs;
    Spec="&label"; Sex="&sx"; Outcome="&outcome";
   run;
   proc append base=work.audit_model_n data=work.audit_nobs force; run;
   %if not %sysfunc(exist(work.adj_ls)) or not %sysfunc(exist(work.adj_diff)) %then %do;
    %put ERROR: Adjusted estimates or contrasts were not produced.;
    %abort cancel;
   %end;
   data work.adj_ls;
    length Spec $16 Sex $6 Outcome $12;
    set work.adj_ls;
    Spec="&label"; Sex="&sx"; Outcome="&outcome";
   run;
   data work.adj_diff;
    length Spec $16 Sex $6 Outcome $12;
    set work.adj_diff;
    Spec="&label"; Sex="&sx"; Outcome="&outcome";
   run;
   proc append base=work.adj_ls_all data=work.adj_ls; run;
   proc append base=work.adj_diff_all data=work.adj_diff; run;

  %end;
 %end;
%end;
%mend;
%audit;

data work.adjusted_estimates;
 set work.adj_ls_all;
 length factor $8 level $30 cat $20;
 select (upcase(Effect));
  when ('AGE_PRINT') do; factor='age10'; level=AGE_PRINT; end;
  when ('EDU_PRINT') do; factor='edu'; level=EDU_PRINT; end;
  when ('INCOME_PRINT') do; factor='inc'; level=INCOME_PRINT; end;
  otherwise do; factor='UNKNOWN'; level='UNKNOWN'; end;
 end;
 select (Outcome);
  when ('Y_NEITHER') cat='Neither';
  when ('Y_AERONLY') cat='Aerobic only';
  when ('Y_STRONLY') cat='Strength only';
  when ('Y_BOTH') cat='Both';
  otherwise cat='UNKNOWN';
 end;
 est=100*Estimate;
 if not missing(DF) and DF>0 then critical=tinv(0.975,DF);
 else critical=.;
 lcl=100*(Estimate-critical*StdErr);
 ucl=100*(Estimate+critical*StdErr);
run;

/* Preserve full numeric values in both native SAS files and CSV. */
libname finalout "&OUTDIR";
data finalout.final_margins;
 set work.adjusted_estimates;
 format _numeric_ best32.;
run;
data finalout.final_differences;
 set work.adj_diff_all;
 format _numeric_ best32.;
run;
data finalout.final_model_n;
 set work.audit_model_n;
 format _numeric_ best32.;
run;
/* Prespecified contrasts: first category minus second. */
data finalout.final_contrasts;
 set work.adj_diff_all;
 length Contrast $40;
 Direction=.;
 if upcase(Effect)='AGE_PRINT' then do;
  Contrast='80+ vs 20-29';
  if AGE_PRINT='80+' and _AGE_PRINT='20-29' then Direction=1;
  if AGE_PRINT='20-29' and _AGE_PRINT='80+' then Direction=-1;
 end;
 if upcase(Effect)='EDU_PRINT' then do;
  Contrast='College+ vs Elementary';
  if EDU_PRINT='College+' and _EDU_PRINT='Elementary' then Direction=1;
  if EDU_PRINT='Elementary' and _EDU_PRINT='College+' then Direction=-1;
 end;
 if upcase(Effect)='INCOME_PRINT' then do;
  Contrast='High vs Low';
  if INCOME_PRINT='High' and _INCOME_PRINT='Low' then Direction=1;
  if INCOME_PRINT='Low' and _INCOME_PRINT='High' then Direction=-1;
 end;
 if missing(Direction) then delete;
 Difference_pp=100*Direction*Estimate;
 if Direction=1 then do; LCL_pp=100*Lower; UCL_pp=100*Upper; end;
 else do; LCL_pp=-100*Upper; UCL_pp=-100*Lower; end;
 P_value=Probt;
 length Significance $3;
 if missing(P_value) then Significance='NA';
 else if P_value<0.001 then Significance='***';
 else if P_value<0.01 then Significance='**';
 else if P_value<0.05 then Significance='*';
 else Significance='NS';
 keep Spec Sex Outcome Contrast Difference_pp LCL_pp UCL_pp P_value Significance DF;
 format _numeric_ best32.;
run;
%macro export_final(ds);
proc export data=finalout.&ds outfile="&OUTDIR/&ds..csv" dbms=csv replace; run;
%mend;
%export_final(final_margins);
%export_final(final_differences);
%export_final(final_contrasts);
%export_final(final_model_n);
proc sql;
 create table work.final_precision_check as
 select a.Spec,a.N_margins,a.Missing_estimates,a.Missing_CI,
 b.N_contrasts,b.Missing_contrasts,b.Missing_p
 from
 (select Spec,count(*) as N_margins,sum(missing(est)) as Missing_estimates,
 sum(missing(lcl) or missing(ucl)) as Missing_CI
 from finalout.final_margins group by Spec) a
 left join
 (select Spec,count(*) as N_contrasts,
 sum(missing(Difference_pp) or missing(LCL_pp) or missing(UCL_pp)) as Missing_contrasts,
 sum(missing(P_value)) as Missing_p
 from finalout.final_contrasts group by Spec) b
 on a.Spec=b.Spec;
quit;
title 'Final precision export checks: expect 136 margins and 24 contrasts per specification';
proc print data=work.final_precision_check noobs; run;
proc export data=work.final_precision_check outfile="&OUTDIR/final_precision_check.csv" dbms=csv replace; run;
title;
ods html close;
ods listing;
