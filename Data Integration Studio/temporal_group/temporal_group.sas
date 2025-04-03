/**
 * Temporal group custom transformation 
 * Used to group tables considering timeline. 
 *
 * Options settings:
 *  import temporal_group.xml in Code Options

 * Inputs/Outputs settings:
 * [v] Transformation supports inputs (min=1, max=1)
 * [v] Transformation supports outputs (min=1, max=1)
 * [v] Automaticallygenerate delete code for outputs
 * [v] Generate column mapping macros
 *
 * https://github.com/dadrico/
*/

%macro timelineGroup;

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

   %let dateFormat=yymmdd10.;

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

   %* Make a list of points in time;
   data TLG_PointsInTime(keep=_md5 _pit);
      length _md5 $32. _pit 8.;
      format _md5 $hex32. _pit &dateFormat.;
      set &_INPUT.;
      _md5=md5(catx('#', &GroupByColumns_comma.));
      _pit=&ValidFromColumn.; output;
      _pit=&ValidToColumn.; output;
   run;

   %* Remove duplicates;
   proc sort data=TLG_PointsInTime nodupkey;
      by _md5 _pit;
   run;

   %* Remove first and last point in time per key;
   data TLG_MiddlePointsInTime;
      set TLG_PointsInTime;
      by _md5;
      if ^(first._md5 or last._md5) then output;
   run;

   %* Cut periods if point in time falls inside;
   data TLG_CutPeriods(drop=found _vf _vt _pit _md5);
      set &_INPUT.;

      length found _vf _vt 8.;

      if 1=0 then set TLG_MiddlePointsInTime;
      call missing(_md5, _pit);

      if _N_=1 then do;
         declare hash pit(dataset: "TLG_MiddlePointsInTime" , ordered: "A", multidata: "Y");
         pit.definekey("_md5");
         pit.definedata("_pit");
         pit.definedone();
      end;

      _vf=&ValidFromColumn.;
      _vt=&ValidToColumn.;

      _md5=md5(catx('#', &GroupByColumns_comma.));
      found=(pit.find()=0);
      do while (found);
         if _pit>_vf and _pit<_vt then do;
            &ValidFromColumn.=_vf;
            &ValidToColumn.=_pit;
            output;
            _vf=_pit;
         end;
         found=(pit.find_next()=0);
      end;
      &ValidFromColumn.=_vf;
      &ValidToColumn.=_vt;
      output;
   run;

   %* Perform group by on cut periods;
   proc sql;
      create table TLG_GroupedBy as
      select 
         &_OUTPUT_col0_calc.
         %do i=1 %to &_OUTPUT_col_count.-1;
            , &&_OUTPUT_col&i._calc.
         %end;
      from TLG_CutPeriods
      group by &GroupByColumns_comma., &ValidFromColumn., &ValidToColumn.
      order by &GroupByColumns_comma., &ValidFromColumn.;
   quit;


   %* Merge periods if the data is identical;
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
      set TLG_GroupedBy (rename=(%do i=0 %to &_OUTPUT_col_count.-1; 
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

      retain   %do i=0 %to &_OUTPUT_col_count.-1; 
                  &&_OUTPUT_col&i._name.
               %end; 
            _last_identical
            _keep_date ;

      if _n_>1 %do i=0 %to &_OUTPUT_col_count.-1; 
                  %if %sysfunc(findw(&validFromColumn. &validToColumn., &&_OUTPUT_col&i._name.))=0 %then %do;
                     and _next_col&i.=&&_OUTPUT_col&i._name.
                  %end;
               %end; 
      then do;
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
         delete TLG_:;
      run;
   %end;

%mend timelineGroup;
%timelineGroup;
