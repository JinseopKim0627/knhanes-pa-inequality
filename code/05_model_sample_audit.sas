options nodate nonumber;
proc datasets library=work nolist;
 delete audit_model_n audit_nobs;
quit;
libname recov "&OUTDIR" access=readonly;
ods html path="&OUTDIR" file="model_audit.html";
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
  %do spec=1 %to 4;
   %let wt=WT_MAIN;
   %let extra=;
   %let filt=1;
   %let label=MAIN;
   %if &spec=2 %then %do; %let label=NOCOVID; %let filt=SURVEY_YEAR not in (2020,2021); %let wt=WT_NOCOVID; %end;
   %if &spec=3 %then %do; %let label=NO2014; %let filt=SURVEY_YEAR ne 2014; %let wt=WT_NO2014; %end;
   %if &spec=4 %then %do; %let label=BMICHRONIC; %let extra=BMI_CAT CHRONIC_CAT; %end;
   data work.model_data;
    set recov.pa4_main2014_v5;
    where SEX_PRINT="&sx" and (&filt);
    WT_NO2014=MY_WT/9;
   run;
   proc datasets library=work nolist; delete audit_nobs; quit;
   ods exclude all;
   ods output DataSummary=work.audit_nobs;
   proc surveyreg data=work.model_data;
    strata UNIFIED_STRATA;
    cluster UNIFIED_PSU;
    weight &wt;
    class AGE_PRINT EDU_PRINT INCOME_PRINT YEAR_PRINT &extra;
    model &outcome=AGE_PRINT EDU_PRINT INCOME_PRINT YEAR_PRINT &extra / solution;
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
  %end;
 %end;
%end;
%mend;
%audit;
proc print data=work.audit_model_n noobs; run;
proc export data=work.audit_model_n outfile="&OUTDIR/model_n_audit.csv" dbms=csv replace; run;
ods html close;
ods listing;
