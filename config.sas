/* ------------------------------------------------------------------
   Set these two paths, then run this file before any script in code/.
   Run SAS in a Unicode (UTF-8) session.
   ------------------------------------------------------------------ */

/* Folder containing the KNHANES raw SAS files (HN07_ALL ... HN23_ALL) */
%let RAWDIR = C:/path/to/KNHANES/raw;

/* Folder where the analytic dataset and result files will be written */
%let OUTDIR = C:/path/to/output;
