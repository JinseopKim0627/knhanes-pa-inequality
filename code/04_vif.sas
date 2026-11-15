/* Design-matrix diagnostic only. Survey inference remains in SURVEYREG.
Reference levels: age 20-29, Elementary, Low income, year 2014.
VIF is coefficient/reference-coding specific, not a factor-level GVIF.
Same predictors and analysis sample for all four primary outcomes. */
options nodate nonumber;
libname recov "&OUTDIR" access=readonly;
ods html path="&OUTDIR" file="vif_check.html";
proc datasets lib=work nolist; delete vif_detail vif_nobs; quit;
data work.vif_input;
 set recov.pa4_main2014_v5;
 AGE_1=(AGE_PRINT="30-39");
 label AGE_1="AGE_PRINT: 30-39";
 AGE_2=(AGE_PRINT="40-49");
 label AGE_2="AGE_PRINT: 40-49";
 AGE_3=(AGE_PRINT="50-59");
 label AGE_3="AGE_PRINT: 50-59";
 AGE_4=(AGE_PRINT="60-69");
 label AGE_4="AGE_PRINT: 60-69";
 AGE_5=(AGE_PRINT="70-79");
 label AGE_5="AGE_PRINT: 70-79";
 AGE_6=(AGE_PRINT="80+");
 label AGE_6="AGE_PRINT: 80+";
 EDU_1=(EDU_PRINT="Middle");
 label EDU_1="EDU_PRINT: Middle";
 EDU_2=(EDU_PRINT="High");
 label EDU_2="EDU_PRINT: High";
 EDU_3=(EDU_PRINT="College+");
 label EDU_3="EDU_PRINT: College+";
 EDU_4=(EDU_PRINT="Missing");
 label EDU_4="EDU_PRINT: Missing";
 INC_1=(INCOME_PRINT="Mid-Low");
 label INC_1="INCOME_PRINT: Mid-Low";
 INC_2=(INCOME_PRINT="Mid-High");
 label INC_2="INCOME_PRINT: Mid-High";
 INC_3=(INCOME_PRINT="High");
 label INC_3="INCOME_PRINT: High";
 INC_4=(INCOME_PRINT="Missing");
 label INC_4="INCOME_PRINT: Missing";
 YEAR_2015=(SURVEY_YEAR=2015);
 YEAR_2016=(SURVEY_YEAR=2016);
 YEAR_2017=(SURVEY_YEAR=2017);
 YEAR_2018=(SURVEY_YEAR=2018);
 YEAR_2019=(SURVEY_YEAR=2019);
 YEAR_2020=(SURVEY_YEAR=2020);
 YEAR_2021=(SURVEY_YEAR=2021);
 YEAR_2022=(SURVEY_YEAR=2022);
 YEAR_2023=(SURVEY_YEAR=2023);
run;
%macro run_vif;
 %local s sex method mode;
 %do s=1 %to 2;
  %let sex=%scan(Male Female,&s);
  %do method=1 %to 2;
   %let mode=Survey_weighted;
   %if &method=2 %then %let mode=Unweighted;
   proc datasets lib=work nolist; delete vif_pe vif_n; quit;
   ods exclude all;
   ods output ParameterEstimates=work.vif_pe NObs=work.vif_n;
   proc reg data=work.vif_input(where=(SEX_PRINT="&sex"));
    %if &method=1 %then %do; weight WT_MAIN; %end;
    model Y_NEITHER=AGE_1 AGE_2 AGE_3 AGE_4 AGE_5 AGE_6 EDU_1 EDU_2 EDU_3 EDU_4 INC_1 INC_2 INC_3 INC_4 YEAR_2015 YEAR_2016 YEAR_2017 YEAR_2018 YEAR_2019 YEAR_2020 YEAR_2021 YEAR_2022 YEAR_2023 / vif tol;
   run;
   quit;
   ods output close;
   ods exclude none;
   %if not %sysfunc(exist(work.vif_pe)) %then %do;
    %put ERROR: VIF output missing for &sex &mode.;
    %abort cancel;
   %end;
   data work.vif_pe;
    length Sex $6 Method $20;
    set work.vif_pe;
    where upcase(Variable) ne 'INTERCEPT';
    Sex="&sex"; Method="&mode";
    VIF=VarianceInflation;
    keep Sex Method Variable Label DF VIF Tolerance;
   run;
   proc append base=work.vif_detail data=work.vif_pe; run;
   data work.vif_n;
    length Sex $6 Method $20;
    set work.vif_n;
    Sex="&sex"; Method="&mode";
   run;
   proc append base=work.vif_nobs data=work.vif_n; run;
  %end;
 %end;
%mend;
%run_vif;
proc sql;
 create table work.vif_summary as
 select Sex,Method,count(*) as N_predictors,
 sum(missing(VIF)) as N_missing_VIF,
 min(Tolerance) as Min_tolerance,
 max(VIF) as Max_VIF,mean(VIF) as Mean_VIF,
 sum(VIF>=5) as N_VIF_GE5,sum(VIF>=10) as N_VIF_GE10
 from work.vif_detail group by Sex,Method;
 create table work.vif_maximum as
 select a.* from work.vif_detail a inner join work.vif_summary b
 on a.Sex=b.Sex and a.Method=b.Method and a.VIF=b.Max_VIF;
quit;
title 'VIF summary: 23 indicators per sex, including missing categories';
proc print data=work.vif_summary noobs; format Min_tolerance Max_VIF Mean_VIF 10.4; run;
title 'Predictors with the highest VIF';
proc print data=work.vif_maximum noobs; run;
title 'Number of observations used';
proc print data=work.vif_nobs noobs; run;
%macro save(ds);
proc export data=work.&ds outfile="&OUTDIR/&ds..csv" dbms=csv replace; run;
%mend;
%save(vif_summary); %save(vif_detail); %save(vif_nobs);
ods html close;
ods listing;
title;
