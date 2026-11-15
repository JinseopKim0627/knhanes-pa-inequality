/* Run in a SAS Unicode (UTF-8) session. */
%macro check_encoding;
 %put NOTE: Current SAS session encoding = %sysfunc(getoption(encoding));
 %if "%upcase(%sysfunc(getoption(encoding)))" ne "UTF-8" and "%upcase(%sysfunc(getoption(encoding)))" ne "UTF8" %then %do;
  %put ERROR: Start SAS with Unicode UTF-8 support before running this file.;
  %abort cancel;
 %end;
%mend;
%check_encoding;
options errorcheck=strict;
/* ========================================================= */
/* KNHANES 2007-2023: PA Analysis FINAL CLEAN CODE           */
/* Revised for professor feedback and stricter missing rules */
/*                                                           */
/* Outcomes:                                                 */
/*   PA_AEROBIC    = MVPA-equivalent >=150 min/week          */
/*   PA_RESISTANCE = strength >=2 days/week                  */
/*   PA_ACTIVE     = MVPA-equivalent >=150 + strength >=2    */
/*   PA4           = 4 mutually exclusive PA groups          */
/*                                                           */
/* Key revision:                                             */
/*   Aerobic and resistance valid flags are handled           */
/*   separately. Missing PA components are not silently       */
/*   coded as 0 unless the respondent explicitly answered no. */
/* ========================================================= */

options nodate nonumber varlenchk=nowarn;
ods graphics on;


/* ========================================================= */
/* 0) PATH SETTING                                           */
/* ========================================================= */

%let ROOT = &RAWDIR;

libname KNHANES "&ROOT" access=readonly;
ods listing;

%macro VAR_EXISTS(DATAFILE, VAR);
  %local dsid vnum rc;
  %let dsid = %sysfunc(open(KNHANES.&DATAFILE, i));
  %if &dsid %then %do;
    %let vnum = %sysfunc(varnum(&dsid, &VAR));
    %let rc = %sysfunc(close(&dsid));
    %if &vnum > 0 %then 1;
    %else 0;
  %end;
  %else 0;
%mend;


/* ========================================================= */
/* 1) 2007-2013: OLD PA questionnaire                        */
/* ========================================================= */

%macro SIMPLE_OLD(YEAR, DATAFILE);

data work.HN&YEAR._CLEAN;
  set KNHANES.&DATAFILE(keep=
      kstrata psu wt_itvex age sex edu ho_incm
      HE_BMI HE_HP HE_DM HE_HCHOL
      BE3_11 BE3_12 BE3_13 BE3_21 BE3_22 BE3_23 BE5_1);

  attrib _all_ label=' ';

  year = 2000 + &YEAR;

  MY_STRATA = kstrata;

  length MY_PSU $30;
  MY_PSU = cats(psu);

  MY_WT = wt_itvex;

  MY_AGE = age;
  MY_SEX = sex;
  MY_EDU = edu;
  MY_INC = ho_incm;

  MY_BMI   = HE_BMI;
  MY_HP    = HE_HP;
  MY_DM    = HE_DM;
  MY_HCHOL = HE_HCHOL;
  PA_STRENGTH_CODE_RAW = BE5_1;

  /* OLD PA special codes.
     Aerobic frequency: 1 = none, 2-8 = 1-7 days/week; 9/88/99 = missing.
     Strength: BE5_1 = 1 none, 2-6 = 1-5+ days/week; 8/9/88/99 = missing. */
  array old_aer_freq_vars BE3_11 BE3_21;
  do over old_aer_freq_vars;
    if old_aer_freq_vars in (9, 88, 99) then old_aer_freq_vars = .;
  end;

  if BE5_1 in (8, 9, 88, 99) then BE5_1 = .;

  array old_time_vars BE3_12 BE3_13 BE3_22 BE3_23;
  do over old_time_vars;
    if old_time_vars in (88, 99, 888, 999) then old_time_vars = .;
  end;

  /* OLD questionnaire assumption: 1 = none, 2-8 = 1-7 days/week */
  PA_VIG_FREQ = .;
  PA_MOD_FREQ = .;
  PA_STRENGTH_FREQ = .;

  if BE3_11 = 1 then PA_VIG_FREQ = 0;
  else if 2 <= BE3_11 and BE3_11 <= 8 then PA_VIG_FREQ = BE3_11 - 1;

  if BE3_21 = 1 then PA_MOD_FREQ = 0;
  else if 2 <= BE3_21 and BE3_21 <= 8 then PA_MOD_FREQ = BE3_21 - 1;

  if BE5_1 = 1 then PA_STRENGTH_FREQ = 0;
  else if 2 <= BE5_1 and BE5_1 <= 6 then PA_STRENGTH_FREQ = BE5_1 - 1;

  VIG_MIN_DAY = .;
  MOD_MIN_DAY = .;

  if PA_VIG_FREQ = 0 then VIG_MIN_DAY = 0;
  else if PA_VIG_FREQ > 0 then do;
    if BE3_12 ne . or BE3_13 ne . then
      VIG_MIN_DAY = sum(coalesce(BE3_12,0)*60, coalesce(BE3_13,0));
  end;

  if PA_MOD_FREQ = 0 then MOD_MIN_DAY = 0;
  else if PA_MOD_FREQ > 0 then do;
    if BE3_22 ne . or BE3_23 ne . then
      MOD_MIN_DAY = sum(coalesce(BE3_22,0)*60, coalesce(BE3_23,0));
  end;

  PA_VIG_DUR_WEEK = .;
  PA_MOD_DUR_WEEK = .;

  if PA_VIG_FREQ ne . and VIG_MIN_DAY ne . then
    PA_VIG_DUR_WEEK = PA_VIG_FREQ * VIG_MIN_DAY;

  if PA_MOD_FREQ ne . and MOD_MIN_DAY ne . then
    PA_MOD_DUR_WEEK = PA_MOD_FREQ * MOD_MIN_DAY;

  PA_VIG_VALID = (PA_VIG_FREQ ne . and VIG_MIN_DAY ne .);
  PA_MOD_VALID = (PA_MOD_FREQ ne . and MOD_MIN_DAY ne .);
  PA_AER_VALID = (PA_VIG_VALID = 1 and PA_MOD_VALID = 1);
  PA_RES_VALID = (PA_STRENGTH_FREQ ne .);
  PA_ANY_VALID = (PA_AER_VALID = 1 or PA_RES_VALID = 1);
  PA_VALID = (PA_AER_VALID = 1 and PA_RES_VALID = 1);

  keep year MY_PSU MY_STRATA MY_WT
       MY_AGE MY_SEX MY_EDU MY_INC
       MY_BMI MY_HP MY_DM MY_HCHOL
       PA_VIG_DUR_WEEK PA_MOD_DUR_WEEK PA_STRENGTH_FREQ PA_STRENGTH_CODE_RAW
       PA_VIG_VALID PA_MOD_VALID PA_AER_VALID PA_RES_VALID PA_ANY_VALID PA_VALID;

run;

%mend;

%SIMPLE_OLD(07, HN07_ALL);
%SIMPLE_OLD(08, HN08_ALL);
%SIMPLE_OLD(09, HN09_ALL);
%SIMPLE_OLD(10, HN10_ALL);
%SIMPLE_OLD(11, HN11_ALL);
%SIMPLE_OLD(12, HN12_ALL);
%SIMPLE_OLD(13, HN13_ALL);


/* ========================================================= */
/* 2) 2014-2023: NEW PA questionnaire                        */
/* ========================================================= */

%macro SIMPLE_NEW(YEAR, DATAFILE);

data work.HN&YEAR._CLEAN;
  set KNHANES.&DATAFILE(keep=
      kstrata psu wt_itvex age sex edu ho_incm
      HE_BMI HE_HP
      %if &YEAR <= 18 %then %do; HE_DM %end;
      %else %do; HE_DM_HbA1c %end;
      HE_HCHOL
      BE3_71 BE3_72 BE3_73 BE3_74
      BE3_81 BE3_82 BE3_83 BE3_84
      BE3_91 BE3_92 BE3_93 BE3_94
      BE3_75 BE3_76 BE3_77 BE3_78
      BE3_85 BE3_86 BE3_87 BE3_88
      BE5_1);

  attrib _all_ label=' ';

  year = 2000 + &YEAR;

  MY_STRATA = kstrata;

  length MY_PSU $30;
  MY_PSU = cats(psu);

  MY_WT = wt_itvex;

  MY_AGE = age;
  MY_SEX = sex;
  MY_EDU = edu;
  MY_INC = ho_incm;

  MY_BMI   = HE_BMI;
  MY_HP    = HE_HP;
  MY_HCHOL = HE_HCHOL;

  /* Diabetes variable changed across KNHANES years.
     2014-2018: HE_DM
     2019-2023: HE_DM_HbA1c */
  %if &YEAR <= 18 %then %do;
    MY_DM = HE_DM;
  %end;
  %else %do;
    MY_DM = HE_DM_HbA1c;
  %end;
  PA_STRENGTH_CODE_RAW = BE5_1;

  /* NEW PA special codes.
     Indicators: 1=yes, 2=no, 8/9/88/99=missing.
     Days: 1-7 valid, 8/9/88/99=missing.
     Strength: BE5_1 = 1 none, 2-6 = 1-5+ days/week; 8/9/88/99 = missing.
     Time: 88/99/888/999=missing. */
  array new_ind_vars BE3_71 BE3_81 BE3_91 BE3_75 BE3_85;
  do over new_ind_vars;
    if new_ind_vars in (8, 9, 88, 99) then new_ind_vars = .;
  end;

  array new_day_vars BE3_72 BE3_82 BE3_92 BE3_76 BE3_86;
  do over new_day_vars;
    if new_day_vars in (8, 9, 88, 99) then new_day_vars = .;
  end;

  if BE5_1 in (8, 9, 88, 99) then BE5_1 = .;

  array new_time_vars BE3_73 BE3_74 BE3_83 BE3_84 BE3_93 BE3_94
                      BE3_77 BE3_78 BE3_87 BE3_88;
  do over new_time_vars;
    if new_time_vars in (88, 99, 888, 999) then new_time_vars = .;
  end;

  PA_STRENGTH_FREQ = .;

  if BE5_1 = 1 then PA_STRENGTH_FREQ = 0;
  else if 2 <= BE5_1 and BE5_1 <= 6 then PA_STRENGTH_FREQ = BE5_1 - 1;

  PA_RES_VALID = (PA_STRENGTH_FREQ ne .);

  /* NEW questionnaire assumption: domain indicator 1 = yes, 2 = no. */
  WORK_VIG = .;
  WORK_MOD = .;
  TRANS_MOD = .;
  LEIS_VIG = .;
  LEIS_MOD = .;

  WORK_VIG_VALID = 0;
  WORK_MOD_VALID = 0;
  TRANS_MOD_VALID = 0;
  LEIS_VIG_VALID = 0;
  LEIS_MOD_VALID = 0;

  if BE3_71 = 2 then do;
    WORK_VIG = 0;
    WORK_VIG_VALID = 1;
  end;
  else if BE3_71 = 1 then do;
    if BE3_72 ne . and (BE3_73 ne . or BE3_74 ne .) then do;
      WORK_VIG = BE3_72 * ((coalesce(BE3_73,0)*60) + coalesce(BE3_74,0));
      WORK_VIG_VALID = 1;
    end;
  end;

  if BE3_81 = 2 then do;
    WORK_MOD = 0;
    WORK_MOD_VALID = 1;
  end;
  else if BE3_81 = 1 then do;
    if BE3_82 ne . and (BE3_83 ne . or BE3_84 ne .) then do;
      WORK_MOD = BE3_82 * ((coalesce(BE3_83,0)*60) + coalesce(BE3_84,0));
      WORK_MOD_VALID = 1;
    end;
  end;

  if BE3_91 = 2 then do;
    TRANS_MOD = 0;
    TRANS_MOD_VALID = 1;
  end;
  else if BE3_91 = 1 then do;
    if BE3_92 ne . and (BE3_93 ne . or BE3_94 ne .) then do;
      TRANS_MOD = BE3_92 * ((coalesce(BE3_93,0)*60) + coalesce(BE3_94,0));
      TRANS_MOD_VALID = 1;
    end;
  end;

  if BE3_75 = 2 then do;
    LEIS_VIG = 0;
    LEIS_VIG_VALID = 1;
  end;
  else if BE3_75 = 1 then do;
    if BE3_76 ne . and (BE3_77 ne . or BE3_78 ne .) then do;
      LEIS_VIG = BE3_76 * ((coalesce(BE3_77,0)*60) + coalesce(BE3_78,0));
      LEIS_VIG_VALID = 1;
    end;
  end;

  if BE3_85 = 2 then do;
    LEIS_MOD = 0;
    LEIS_MOD_VALID = 1;
  end;
  else if BE3_85 = 1 then do;
    if BE3_86 ne . and (BE3_87 ne . or BE3_88 ne .) then do;
      LEIS_MOD = BE3_86 * ((coalesce(BE3_87,0)*60) + coalesce(BE3_88,0));
      LEIS_MOD_VALID = 1;
    end;
  end;

  PA_VIG_VALID = (WORK_VIG_VALID = 1 and LEIS_VIG_VALID = 1);
  PA_MOD_VALID = (WORK_MOD_VALID = 1 and TRANS_MOD_VALID = 1 and LEIS_MOD_VALID = 1);
  PA_AER_VALID = (PA_VIG_VALID = 1 and PA_MOD_VALID = 1);

  PA_VIG_DUR_WEEK = .;
  PA_MOD_DUR_WEEK = .;

  if PA_VIG_VALID = 1 then PA_VIG_DUR_WEEK = sum(WORK_VIG, LEIS_VIG);
  if PA_MOD_VALID = 1 then PA_MOD_DUR_WEEK = sum(WORK_MOD, TRANS_MOD, LEIS_MOD);

  PA_ANY_VALID = (PA_AER_VALID = 1 or PA_RES_VALID = 1);
  PA_VALID = (PA_AER_VALID = 1 and PA_RES_VALID = 1);

  keep year MY_PSU MY_STRATA MY_WT
       MY_AGE MY_SEX MY_EDU MY_INC
       MY_BMI MY_HP MY_DM MY_HCHOL
       PA_VIG_DUR_WEEK PA_MOD_DUR_WEEK PA_STRENGTH_FREQ PA_STRENGTH_CODE_RAW
       LEIS_VIG LEIS_MOD LEIS_VIG_VALID LEIS_MOD_VALID
       PA_VIG_VALID PA_MOD_VALID PA_AER_VALID PA_RES_VALID PA_ANY_VALID PA_VALID;

run;

%mend;

%SIMPLE_NEW(14, HN14_ALL);
%SIMPLE_NEW(15, HN15_ALL);
%SIMPLE_NEW(16, HN16_ALL);
%SIMPLE_NEW(17, HN17_ALL);
%SIMPLE_NEW(18, HN18_ALL);
%SIMPLE_NEW(19, HN19_ALL);
%SIMPLE_NEW(20, HN20_ALL);
%SIMPLE_NEW(21, HN21_ALL);
%SIMPLE_NEW(22, HN22_ALL);
%SIMPLE_NEW(23, HN23_ALL);


/* ========================================================= */
/* 3) MERGE + DERIVED VARIABLES                              */
/* ========================================================= */

%macro check_loaded;
 %local dsid n rc;
 %do yr=7 %to 23;
  %let yy=%sysfunc(putn(&yr,z2.));
  %let dsid=%sysfunc(open(work.HN&yy._CLEAN));
  %if &dsid=0 %then %do; %put ERROR: Missing annual data &yy.; %abort cancel; %end;
  %let n=%sysfunc(attrn(&dsid,nobs));
  %let rc=%sysfunc(close(&dsid));
  %if &n=0 %then %do; %put ERROR: Empty annual data &yy. No results will be saved.; %abort cancel; %end;
 %end;
%mend;
%check_loaded;

data work.PRE_SELECTION;
  set
    work.HN07_CLEAN work.HN08_CLEAN work.HN09_CLEAN
    work.HN10_CLEAN work.HN11_CLEAN work.HN12_CLEAN work.HN13_CLEAN
    work.HN14_CLEAN work.HN15_CLEAN work.HN16_CLEAN
    work.HN17_CLEAN work.HN18_CLEAN work.HN19_CLEAN
    work.HN20_CLEAN work.HN21_CLEAN work.HN22_CLEAN work.HN23_CLEAN;

  if not missing(MY_STRATA) then UNIFIED_STRATA = year*100000 + MY_STRATA;
  else UNIFIED_STRATA = .;

  length UNIFIED_PSU $50;
  UNIFIED_PSU = cats(year, '_', MY_PSU);

  if not missing(MY_WT) then MY_WT_POOL = MY_WT / 17;
  else MY_WT_POOL = .;

  /* Plausibility check: >10080 min/week exceeds 24 h/day for 7 days. */
  if PA_VIG_DUR_WEEK > 10080 then do;
    PA_VIG_DUR_WEEK = .;
    PA_VIG_VALID = 0;
  end;

  if PA_MOD_DUR_WEEK > 10080 then do;
    PA_MOD_DUR_WEEK = .;
    PA_MOD_VALID = 0;
  end;

  PA_AER_VALID = (PA_VIG_VALID = 1 and PA_MOD_VALID = 1);
  PA_RES_VALID = (PA_STRENGTH_FREQ ne .);
  PA_ANY_VALID = (PA_AER_VALID = 1 or PA_RES_VALID = 1);
  PA_VALID = (PA_AER_VALID = 1 and PA_RES_VALID = 1);

  TOTAL_EQ_MOD = .;
  if PA_AER_VALID = 1 then TOTAL_EQ_MOD = sum(PA_MOD_DUR_WEEK, 2*PA_VIG_DUR_WEEK);

  if TOTAL_EQ_MOD > 10080 then do;
    TOTAL_EQ_MOD = .;
    PA_AER_VALID = 0;
    PA_ANY_VALID = (PA_AER_VALID = 1 or PA_RES_VALID = 1);
    PA_VALID = (PA_AER_VALID = 1 and PA_RES_VALID = 1);
  end;

  if PA_AER_VALID = 1 then PA_AEROBIC = (TOTAL_EQ_MOD >= 150);
  else PA_AEROBIC = .;

  if PA_RES_VALID = 1 then PA_RESISTANCE = (PA_STRENGTH_FREQ >= 2);
  else PA_RESISTANCE = .;

  if PA_AER_VALID = 1 and PA_RES_VALID = 1 then
    PA_ACTIVE = (TOTAL_EQ_MOD >= 150 and PA_STRENGTH_FREQ >= 2);
  else PA_ACTIVE = .;

  length PA4_LABEL $30;

  if PA_AEROBIC ne . and PA_RESISTANCE ne . then do;
    if PA_AEROBIC = 0 and PA_RESISTANCE = 0 then do;
      PA4 = 0;
      PA4_LABEL = "Neither";
    end;
    else if PA_AEROBIC = 1 and PA_RESISTANCE = 0 then do;
      PA4 = 1;
      PA4_LABEL = "Aerobic only";
    end;
    else if PA_AEROBIC = 0 and PA_RESISTANCE = 1 then do;
      PA4 = 2;
      PA4_LABEL = "Resistance only";
    end;
    else if PA_AEROBIC = 1 and PA_RESISTANCE = 1 then do;
      PA4 = 3;
      PA4_LABEL = "Both";
    end;
  end;
  else do;
    PA4 = .;
    PA4_LABEL = "";
  end;

  AGE_G  = floor(MY_AGE/5)*5;
  COHORT = floor((year - MY_AGE)/5)*5;
  BIRTH_YEAR = year - MY_AGE;

  length AGE10_LABEL $10;

  if 20 <= MY_AGE and MY_AGE < 30 then do;
    AGE10 = 1;
    AGE10_LABEL = "20-29";
  end;
  else if 30 <= MY_AGE and MY_AGE < 40 then do;
    AGE10 = 2;
    AGE10_LABEL = "30-39";
  end;
  else if 40 <= MY_AGE and MY_AGE < 50 then do;
    AGE10 = 3;
    AGE10_LABEL = "40-49";
  end;
  else if 50 <= MY_AGE and MY_AGE < 60 then do;
    AGE10 = 4;
    AGE10_LABEL = "50-59";
  end;
  else if 60 <= MY_AGE and MY_AGE < 70 then do;
    AGE10 = 5;
    AGE10_LABEL = "60-69";
  end;
  else if 70 <= MY_AGE and MY_AGE < 80 then do;
    AGE10 = 6;
    AGE10_LABEL = "70-79";
  end;
  else if MY_AGE >= 80 then do;
    AGE10 = 7;
    AGE10_LABEL = "80+";
  end;

  length COHORT10_LABEL $15;

  if 1930 <= BIRTH_YEAR and BIRTH_YEAR < 1940 then do;
    COHORT10 = 1;
    COHORT10_LABEL = "1930s";
  end;
  else if 1940 <= BIRTH_YEAR and BIRTH_YEAR < 1950 then do;
    COHORT10 = 2;
    COHORT10_LABEL = "1940s";
  end;
  else if 1950 <= BIRTH_YEAR and BIRTH_YEAR < 1960 then do;
    COHORT10 = 3;
    COHORT10_LABEL = "1950s";
  end;
  else if 1960 <= BIRTH_YEAR and BIRTH_YEAR < 1970 then do;
    COHORT10 = 4;
    COHORT10_LABEL = "1960s";
  end;
  else if 1970 <= BIRTH_YEAR and BIRTH_YEAR < 1980 then do;
    COHORT10 = 5;
    COHORT10_LABEL = "1970s";
  end;
  else if 1980 <= BIRTH_YEAR and BIRTH_YEAR < 1990 then do;
    COHORT10 = 6;
    COHORT10_LABEL = "1980s";
  end;
  else if 1990 <= BIRTH_YEAR and BIRTH_YEAR <= 1995 then do;
    COHORT10 = 7;
    COHORT10_LABEL = "1990-1995";
  end;
  else do;
    COHORT10 = .;
    COHORT10_LABEL = "";
  end;

  length SEX_CAT $7 EDU_CAT $12 INCOME_CAT $10;

  if MY_SEX = 1 then SEX_CAT = 'Male';
  else if MY_SEX = 2 then SEX_CAT = 'Female';
  else SEX_CAT = 'Missing';

  if MY_EDU = 1 then EDU_CAT = 'Elementary';
  else if MY_EDU = 2 then EDU_CAT = 'Middle';
  else if MY_EDU = 3 then EDU_CAT = 'High';
  else if MY_EDU = 4 then EDU_CAT = 'College+';
  else EDU_CAT = 'Missing';

  if MY_INC = 1 then INCOME_CAT = 'Low';
  else if MY_INC = 2 then INCOME_CAT = 'Mid-Low';
  else if MY_INC = 3 then INCOME_CAT = 'Mid-High';
  else if MY_INC = 4 then INCOME_CAT = 'High';
  else INCOME_CAT = 'Missing';

  BMI = MY_BMI;

  length BMI_CAT $12;

  if BMI ne . then do;
    if BMI < 18.5 then BMI_CAT = "Underweight";
    else if 18.5 <= BMI and BMI < 23 then BMI_CAT = "Normal";
    else if 23 <= BMI and BMI < 25 then BMI_CAT = "Overweight";
    else if BMI >= 25 then BMI_CAT = "Obesity";
  end;
  else BMI_CAT = "Missing";

  HTN = .;
  DM = .;
  HCHOL = .;

  /* Hypertension.
     HE_HP coding:
     1/2 = non-hypertension categories
     3/4 = hypertension-related categories. */
  if MY_HP in (3, 4) then HTN = 1;
  else if MY_HP in (1, 2) then HTN = 0;
  else HTN = .;

  /* Diabetes.
     HE_DM / HE_DM_HbA1c coding:
     1 = normal
     2 = impaired fasting glucose / prediabetes
     3 = diabetes. */
  if MY_DM = 3 then DM = 1;
  else if MY_DM in (1, 2) then DM = 0;
  else DM = .;

  /* Hypercholesterolemia.
     HE_HCHOL coding:
     1 = yes
     0 = no. */
  if MY_HCHOL = 1 then HCHOL = 1;
  else if MY_HCHOL = 0 then HCHOL = 0;
  else HCHOL = .;

  CHRONIC_ANY = .;

  if nmiss(HTN, DM, HCHOL) < 3 then do;
    if HTN = 1 or DM = 1 or HCHOL = 1 then CHRONIC_ANY = 1;
    else CHRONIC_ANY = 0;
  end;

  length CHRONIC_CAT $12;

  if CHRONIC_ANY = 1 then CHRONIC_CAT = "Yes";
  else if CHRONIC_ANY = 0 then CHRONIC_CAT = "No";
  else CHRONIC_CAT = "Missing";

  length HTN_CAT DM_CAT HCHOL_CAT $7;

  if HTN = 1 then HTN_CAT = "Yes";
  else if HTN = 0 then HTN_CAT = "No";
  else HTN_CAT = "Missing";

  if DM = 1 then DM_CAT = "Yes";
  else if DM = 0 then DM_CAT = "No";
  else DM_CAT = "Missing";

  if HCHOL = 1 then HCHOL_CAT = "Yes";
  else if HCHOL = 0 then HCHOL_CAT = "No";
  else HCHOL_CAT = "Missing";

run;
data work.TOTAL_FINAL;
  set work.PRE_SELECTION;
  if MY_AGE >= 20;
  if MY_WT_POOL > 0;
  if SEX_CAT in ('Male','Female');
  if PA_ANY_VALID = 1;




run;


/* ========================================================= */
/* 4) ANALYTIC DATASET WITH PERIOD CONTROLS                  */
/* ========================================================= */

%let INDATA  = WORK.TOTAL_FINAL;
%let WT      = MY_WT_POOL;
%let STRATA  = UNIFIED_STRATA;
%let PSU     = UNIFIED_PSU;

data WORK.ANALYTIC;
  set &INDATA;

  SURVEY_YEAR = year;

  length PA_QVER $7;
  if 2007 <= SURVEY_YEAR and SURVEY_YEAR <= 2013 then PA_QVER = 'OLD';
  else if 2014 <= SURVEY_YEAR and SURVEY_YEAR <= 2023 then PA_QVER = 'NEW';
  else PA_QVER = 'UNK';

  SURVEY_CYCLE = floor((SURVEY_YEAR - 2007)/2)*2 + 2007;

  COHORT_P = COHORT;
  if COHORT_P >= 1995 then COHORT_P = 1995;

run;


data WORK.PA4_BASE_ALL;
  set WORK.ANALYTIC;

  length
    SEX_PRINT       $10
    PA4_PRINT       $20
    AGE_PRINT       $10
    COHORT_PRINT    $15
    EDU_PRINT       $20
    INCOME_PRINT    $20
    YEAR_PRINT      $8
    CYCLE_PRINT     $8
    QVER_PRINT      $12;

  if missing(SURVEY_YEAR) then SURVEY_YEAR = year;
  if not (2007 <= SURVEY_YEAR and SURVEY_YEAR <= 2023) then delete;

  YEAR_PRINT  = strip(put(SURVEY_YEAR, 4.));
  CYCLE_PRINT = strip(put(SURVEY_CYCLE, 4.));

  if not missing(MY_WT) then do;
    WT_FULL    = MY_WT / 17;
    WT_MAIN    = MY_WT / 10;
    WT_NOCOVID = MY_WT / 8;
  end;
  else do;
    WT_FULL    = MY_WT_POOL;
    WT_MAIN    = MY_WT_POOL * (17 / 10);
    WT_NOCOVID = MY_WT_POOL * (17 / 8);
  end;

  if WT_FULL <= 0 then delete;

  if SEX_CAT = "Male" then SEX_PRINT = "Male";
  else if SEX_CAT = "Female" then SEX_PRINT = "Female";
  else delete;

  if PA_AEROBIC not in (0, 1) then delete;
  if missing(PA_STRENGTH_FREQ) then delete;

  PA_STRENGTH = (PA_STRENGTH_FREQ >= 2);

  if PA_AEROBIC = 0 and PA_STRENGTH = 0 then
    PA4_PRINT = "Neither";
  else if PA_AEROBIC = 1 and PA_STRENGTH = 0 then
    PA4_PRINT = "Aerobic only";
  else if PA_AEROBIC = 0 and PA_STRENGTH = 1 then
    PA4_PRINT = "Strength only";
  else if PA_AEROBIC = 1 and PA_STRENGTH = 1 then
    PA4_PRINT = "Both";
  else delete;

  Y_NEITHER = (PA4_PRINT = "Neither");
  Y_AERONLY = (PA4_PRINT = "Aerobic only");
  Y_STRONLY = (PA4_PRINT = "Strength only");
  Y_BOTH    = (PA4_PRINT = "Both");

  if 20 <= MY_AGE and MY_AGE < 30 then do;
    AGE_PRINT = "20-29";
    AGE_ORDER = 1;
  end;
  else if 30 <= MY_AGE and MY_AGE < 40 then do;
    AGE_PRINT = "30-39";
    AGE_ORDER = 2;
  end;
  else if 40 <= MY_AGE and MY_AGE < 50 then do;
    AGE_PRINT = "40-49";
    AGE_ORDER = 3;
  end;
  else if 50 <= MY_AGE and MY_AGE < 60 then do;
    AGE_PRINT = "50-59";
    AGE_ORDER = 4;
  end;
  else if 60 <= MY_AGE and MY_AGE < 70 then do;
    AGE_PRINT = "60-69";
    AGE_ORDER = 5;
  end;
  else if 70 <= MY_AGE and MY_AGE < 80 then do;
    AGE_PRINT = "70-79";
    AGE_ORDER = 6;
  end;
  else if MY_AGE >= 80 then do;
    AGE_PRINT = "80+";
    AGE_ORDER = 7;
  end;
  else delete;

  BIRTH_YEAR = SURVEY_YEAR - MY_AGE;

  if 1930 <= BIRTH_YEAR and BIRTH_YEAR < 1940 then do;
    COHORT_PRINT = "1930s";
    COHORT_ORDER = 1;
  end;
  else if 1940 <= BIRTH_YEAR and BIRTH_YEAR < 1950 then do;
    COHORT_PRINT = "1940s";
    COHORT_ORDER = 2;
  end;
  else if 1950 <= BIRTH_YEAR and BIRTH_YEAR < 1960 then do;
    COHORT_PRINT = "1950s";
    COHORT_ORDER = 3;
  end;
  else if 1960 <= BIRTH_YEAR and BIRTH_YEAR < 1970 then do;
    COHORT_PRINT = "1960s";
    COHORT_ORDER = 4;
  end;
  else if 1970 <= BIRTH_YEAR and BIRTH_YEAR < 1980 then do;
    COHORT_PRINT = "1970s";
    COHORT_ORDER = 5;
  end;
  else if 1980 <= BIRTH_YEAR and BIRTH_YEAR < 1990 then do;
    COHORT_PRINT = "1980s";
    COHORT_ORDER = 6;
  end;
  else if 1990 <= BIRTH_YEAR and BIRTH_YEAR <= 1995 then do;
    COHORT_PRINT = "1990-1995";
    COHORT_ORDER = 7;
  end;
  else do;
    COHORT_PRINT = "";
    COHORT_ORDER = .;
  end;

  if EDU_CAT = "Elementary" then do;
    EDU_PRINT = "Elementary";
    EDU_ORDER = 1;
  end;
  else if EDU_CAT = "Middle" then do;
    EDU_PRINT = "Middle";
    EDU_ORDER = 2;
  end;
  else if EDU_CAT = "High" then do;
    EDU_PRINT = "High";
    EDU_ORDER = 3;
  end;
  else if EDU_CAT = "College+" then do;
    EDU_PRINT = "College+";
    EDU_ORDER = 4;
  end;
  else do;
    EDU_PRINT = "Missing";
    EDU_ORDER = 9;
  end;

  if INCOME_CAT = "Low" then do;
    INCOME_PRINT = "Low";
    INCOME_ORDER = 1;
  end;
  else if INCOME_CAT = "Mid-Low" then do;
    INCOME_PRINT = "Mid-Low";
    INCOME_ORDER = 2;
  end;
  else if INCOME_CAT = "Mid-High" then do;
    INCOME_PRINT = "Mid-High";
    INCOME_ORDER = 3;
  end;
  else if INCOME_CAT = "High" then do;
    INCOME_PRINT = "High";
    INCOME_ORDER = 4;
  end;
  else do;
    INCOME_PRINT = "Missing";
    INCOME_ORDER = 9;
  end;

  if 2007 <= SURVEY_YEAR and SURVEY_YEAR <= 2013 then
    QVER_PRINT = "2007-2013";
  else if 2014 <= SURVEY_YEAR and SURVEY_YEAR <= 2023 then
    QVER_PRINT = "2014-2023";
run;


/* ============================================================= */
/* 3. CREATE PRIMARY AND EXTENDED DATASETS                       */
/* ============================================================= */

data WORK.PA4_MAIN2014;
  set WORK.PA4_BASE_ALL;

  if 2014 <= SURVEY_YEAR and SURVEY_YEAR <= 2023;
  if WT_MAIN > 0;
run;


libname recov "&OUTDIR";
data recov.pa4_main2014_v5; set work.PA4_MAIN2014; run;
proc sql;
create table work.recovery_checks as
select count(*) as N_final,
 sum(SEX_CAT='Male') as N_men, sum(SEX_CAT='Female') as N_women,
 sum(missing(PA_AEROBIC)) as Missing_aerobic,
 sum(missing(PA_RESISTANCE)) as Missing_resistance,
 sum(missing(MY_AGE)) as Missing_age,
 sum(missing(UNIFIED_STRATA)) as Missing_strata,
 sum(missing(MY_PSU)) as Missing_original_psu,
 sum(missing(UNIFIED_PSU)) as Missing_unified_psu,
 sum(missing(WT_MAIN) or WT_MAIN<=0) as Invalid_weight,
 sum(EDU_CAT='Missing') as Missing_education,
 sum(INCOME_CAT='Missing') as Missing_income
from work.PA4_MAIN2014;
create table work.sample_flow as
select count(*) as N_all,
 sum(MY_AGE>=20) as N_adults,
 sum(MY_AGE>=20 and MY_WT>0) as N_positive_weight,
 sum(MY_AGE>=20 and MY_WT>0 and SEX_CAT in ('Male','Female')) as N_valid_sex,
 sum(MY_AGE>=20 and MY_WT>0 and SEX_CAT in ('Male','Female') and PA_ANY_VALID=1) as N_any_PA
from work.PRE_SELECTION where year between 2014 and 2023;
quit;
proc export data=work.recovery_checks outfile="&OUTDIR/recovery_checks.csv" dbms=csv replace; run;
proc export data=work.sample_flow outfile="&OUTDIR/sample_flow.csv" dbms=csv replace; run;

ods listing;
proc print data=work.recovery_checks noobs; run;
proc print data=work.sample_flow noobs; run;
