libname recov "&OUTDIR" access=readonly;
ods html path="&OUTDIR" file="table1_check.html";
data work.t1long;
 set recov.pa4_main2014_v5;
 length Factor $12 Level $30;
 Factor='Age'; Level=AGE_PRINT; output;
 Factor='Education'; Level=EDU_PRINT; output;
 Factor='Income'; Level=INCOME_PRINT; output;
 Factor='Activity'; Level=PA4_PRINT; output;
 keep SEX_PRINT WT_MAIN Factor Level;
run;
proc sql;
 create table work.t1tot as select SEX_PRINT, sum(WT_MAIN) as TotalWeight from recov.pa4_main2014_v5 group by SEX_PRINT;
 create table work.table1_check as
 select a.Factor,a.Level,a.SEX_PRINT,count(*) as N,
 100*sum(a.WT_MAIN)/b.TotalWeight as Weighted_pct
 from work.t1long a left join work.t1tot b on a.SEX_PRINT=b.SEX_PRINT
 group by a.Factor,a.Level,a.SEX_PRINT,b.TotalWeight;
quit;
proc print data=work.table1_check noobs; run;
proc export data=work.table1_check outfile="&OUTDIR/table1_check.csv" dbms=csv replace; run;
ods html close;
ods listing;
