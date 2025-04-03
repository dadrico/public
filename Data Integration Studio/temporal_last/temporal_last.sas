/**
 * temporal last custom transformation 
 * Used to deduplicate timeline base on the LAST columns 
 *
* Options settings:
 * import temporal_last.xml in Code Options
 *
 * Inputs/Outputs settings:
 * [v] Transformation supports inputs (min=1, max=1)
 * [v] Transformation supports outputs (min=1, max=1)
 * [v] Automaticallygenerate delete code for outputs
 * [v] Generate column mapping macros
 *
 * https://github.com/dadrico/
*/

%macro timelineLast;

   %let debug=0; 
      %* DEBUG instructions: 
         1. prepare input tables to be available in EG
         2. paste the code of the transformation from the JOB 
            (with all the automatically generated code) into EnterpriseGuide
         3. remove all lines containing: etls_setPerfInit, perfstrt, perfstop, rcSet
         4. set debug above to 1 and run ;

   %if &debug. %then %do;
      options mlogic mprint symbolgen;
   %end;

   %let dateFormat=is8601dt.;

   %if &GroupByColumns_count.= 0 %then %let GroupByColumns_comma=;
   %else %do;
      %let GroupByColumns_compbl = %sysfunc(compbl(&GroupByColumns.)); /* a b c */
      %let GroupByColumns_comma = %sysfunc(translate(&GroupByColumns_compbl.,',',' ')); /* a, b, c */
      %let GroupByColumns_qcomma= %sysfunc(catq(2ac,&GroupByColumns_comma.)); /* "a", "b", "c" */
      %let LastGroupByColumn = &&GroupByColumns&GroupByColumns_count..;
   %end;

   %put ### &=GroupByColumns_qcomma;

   %let validFromColumnIndex = ;
   %let validToColumnIndex = ;
   %let summaryColumns_comma = ;
   %* Prepare useful variables based on mapping definitions ;
   %do i=0 %to &_OUTPUT_col_count.-1;
      %if %sysfunc(findw(&GroupByColumns. &validFromColumn. &validToColumn., &&_OUTPUT_col&i._name.))>0 %then %do;
         %let _OUTPUT_col&i._calc = &&_OUTPUT_col&i._name.;
      %end; %else %do;
      %if &summaryColumns_comma.= %then %do;
         %let summaryColumns_comma = &&_OUTPUT_col&i._name.;
      %end; %else %do;
         %let summaryColumns_comma = &summaryColumns_comma., &&_OUTPUT_col&i._name.;
      %end;
      %if "&&_OUTPUT_col&i._exp."^=""  %then %do;
         %let _OUTPUT_col&i._calc = &&_OUTPUT_col&i._exp. as &&_OUTPUT_col&i._name.;
      %end; %else %do;
         %let _OUTPUT_col&i._calc = &&_OUTPUT_col&i._name.;
      %end;
   %end;

   %put ### _OUTPUT_col&i._calc=&&_OUTPUT_col&i._calc&;
      %if %lowcase(&&_OUTPUT_col&i._name.)=%lowcase(&validFromColumn.) %then %let validFromColumnIndex=&i.;
      %if %lowcase(&&_OUTPUT_col&i._name.)=%lowcase(&validToColumn.) %then %let validToColumnIndex=&i.;
   %end;   

   %if %length(&validFromColumnIndex.)=0 or %length(&validToColumnIndex.)=0 %then %do;
      %put ERROR: Columns &validFromColumn. and &validToColumn. have to be present in the output!;
      %return;
   %end;


   %put ### &=validFromColumnIndex;
   %put ### &=validToColumnIndex;

   %* Create an output view based on mappings;
   proc sql;
      create view TLL_output_view as
      select 
         &_OUTPUT_col0_calc.
         %do i=1 %to &_OUTPUT_col_count.-1;
            , &&_OUTPUT_col&i._calc.
         %end;
      from &_INPUT.;
   quit;

   %* Sort data;
   proc sort data=TLL_output_view out=TLL_SortedSource;
      by &GroupByColumns. &ValidFromColumn. &ValidToColumn.;
   run;

   %* Make a list of points in time;
   data TLL_PointsInTime(keep=&GroupByColumns. _pit);
      set TLL_SortedSource;
      format _pit &dateFormat.;
      _pit=&ValidFromColumn.; output;
      _pit=&ValidToColumn.; output;
   run;

   proc sort data=TLL_PointsInTime nodupkey;
      by &GroupByColumns. _pit;
   run;

   %* Cut periods if point in time falls inside;
   data TLL_CutPeriods(drop=found _tmp_vf _tmp_vt _pit);
      set TLL_SortedSource;
      by &GroupByColumns. &ValidFromColumn. &ValidToColumn.;

      length found _vf _vt _tmp_vf _tmp_vt 8.;
      format _vf _vt _tmp_vf _tmp_vt &dateFormat.;
      if 1=0 then set TLL_PointsInTime(keep=_pit);
      call missing(_pit);

      if _N_=1 then do;
         declare hash pit(dataset: "TLL_PointsInTime" , ordered: "A", multidata: "Y");
         pit.definekey(&GroupByColumns_qcomma.);
         pit.definedata("_pit");
         pit.definedone();
      end;

      _tmp_vf=&ValidFromColumn.;
      _tmp_vt=&ValidToColumn.;

      found=(pit.find()=0);
      do while (found);
         if _pit>_tmp_vf and _pit<_tmp_vt then do;
            _vf=_tmp_vf;
            _vt=_pit;
            output;
            _tmp_vf=_pit;
         end;
         found=(pit.find_next()=0);
      end;
      _vf=_tmp_vf;
      _vt=_tmp_vt;
      output;
   run;

   %* Sort data by key columns and last-by columns ;
   proc sort data=TLL_CutPeriods;
      by &GroupByColumns. _vf _vt &LastByColumns.;
   run;

   %* Select only last records per group in timeline ;
   data TLL_OUTPUT (drop=&ValidFromColumn. &ValidToColumn. rename=(_vf=&ValidFromColumn. _vt=&ValidToColumn.)) 
        %if &_OUTPUT_count.=2 %then &_OUTPUT1. (drop=&ValidFromColumn. &ValidToColumn. rename=(_vf=&ValidFromColumn. _vt=&ValidToColumn.));
        ;
      set TLL_CutPeriods;
      by &GroupByColumns. _vf _vt &LastByColumns.;
      if last._vf then do;
         %if &debug. %then %do;
            out='o';
         %end; %else %do;
            output TLL_OUTPUT;
         %end;
      end;
      %if &debug. %then %do;
         output;
      %end; %else %do;
         %if &_OUTPUT_count.=2 %then else output &_OUTPUT1.;;
      %end;
   run;

   %* Merge periods if the data is identical ;
   data &_OUTPUT.
         %if ^&debug. %then %do;
            (keep=   %do i=0 %to &_OUTPUT_col_count.-1; 
                     %if &i.^=&validFromColumnIndex. %then %do; 
                        &&_OUTPUT_col&i._name. 
                     %end;
                  %end;
                  _keep_date
            rename= (_keep_date=&ValidFromColumn.))
         %end; ;
      set TLL_OUTPUT (rename=(%do i=0 %to &_OUTPUT_col_count.-1; 
                           &&_OUTPUT_col&i._name.=_next_col&i.
                        %end;
                        ) )
                  end=eof ;

      if _n_=1 then do;
         %do i=0 %to &_OUTPUT_col_count.-1; 
            %if &i.=&validFromColumnIndex. %then %do; 
               length _keep_date 8;
               format _keep_date &dateFormat.;
            %end;
            &&_OUTPUT_col&i._name.=_next_col&i.;
            call missing(&&_OUTPUT_col&i._name.);
            format &&_OUTPUT_col&i._name. &&_OUTPUT_col&i._format.;
         %end; ;
         _last_identical=0;
      end; %* just to create new variables ;

      retain    %do i=0 %to &_OUTPUT_col_count.-1; 
               &&_OUTPUT_col&i._name.
            %end; 
            _last_identical
            _keep_date ;

      if _n_>1   %do i=0 %to &_OUTPUT_col_count.-1; 
                  %if %sysfunc(findw(&validFromColumn. &validToColumn., &&_OUTPUT_col&i._name.))=0 %then %do;
                     and _next_col&i.=&&_OUTPUT_col&i._name.
                  %end;
					%end; 
					and _next_col&validFromColumnIndex.=&validToColumn. then do;
         _next_identical=1;
      end;
      else _next_identical=0;

      if ^_last_identical then _keep_date=&ValidFromColumn.;
      
      if _n_>1 and ^_next_identical then 
         %if &debug. %then %do;
            out='o';
         %end;
         output;

      %do i=0 %to &_OUTPUT_col_count.-1; 
         &&_OUTPUT_col&i._name.=_next_col&i.;
      %end; 
      
      _last_identical=_next_identical;
      if ^_last_identical then _keep_date=&ValidFromColumn.;

      if eof then do;
          %do i=0 %to &_OUTPUT_col_count.-1; 
            call missing(_next_col&i.);
         %end; ;      
         output;
      end;
   run;


   %* Cleanup ;
   %if ^&debug. %then %do;
      proc datasets lib=work nolist nowarn;
         delete TLL_:;
      run;
   %end;

%mend timelineLast;
%timelineLast;
