/**
 * temporal join custom transformation 
 * joins 2 tables with timelines based on the given key and join condition
 *
 * Options settings:
 * import temporal_join.xml in Code Options
 *
 * Inputs/Outputs settings:
 * [v] Transformation supports inputs (min=2, max=2)
 * [v] Transformation supports outputs (min=1, max=1)
 * [v] Automaticallygenerate delete code for outputs
 * [v] Generate column mapping macros
 * */

%macro addPrefix(prefix, words);
   %let output=;
   %if %length(&words.)=0 %then %return; 
   %let reverse=%sysfunc(reverse(&words.));
   %let lastChar=%substr("&reverse.",2,1);
   %if &lastChar.^=, %then %let lastChar=;
   %do i=1 %to %sysfunc(countw(&words.),%str(, ));
      %if &i.=1 %then %do;
         %let output=&prefix.%scan(&words.,&i.,%str(, ));
      %end;
      %else %do;
         %let output=&output., &prefix.%scan(&words.,&i.,%str(, ));
      %end;
   %end;
   &output.&lastChar.
%mend addPrefix;

%macro countObs(ds);
   
   %let dsRef=%sysfunc(open(&ds.,IN));
   %let nobs=%sysfunc(attrn(&dsRef.,nobs));
   %let rc=%sysfunc(close(&dsRef.));
   &nobs.

%mend countObs;

%macro timelineJoin;
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

   data _null_;
      EndOfTime="31dec9999 00:00:00"dt;
      call symput('EndOfTime', strip(EndOfTime));
   run;
   %put &=EndOfTime.;
   %let dateFormat=datetime22.;

   %if &keyColumns_count.= 0 %then %let KeyColumns_comma=;
   %else %do;
      %let KeyColumns_compbl = %sysfunc(compbl(&KeyColumns.));
      %let KeyColumns_comma = %sysfunc(translate(&KeyColumns_compbl.,',',' '));
      %let LastKeyColumn = &&KeyColumns&KeyColumns_count..;
   %end;

   %let validFromColumnIndex = ;
   %let validToColumnIndex = ;
   %* Prepare useful variables based on mapping definitions ;
   %do i=0 %to &_OUTPUT_col_count.-1;
      %if %findwi(&keyColumns. &validFromColumn. &validToColumn., &&_OUTPUT_col&i._name.)>0 %then %do;
         %let _OUTPUT_col&i._calc = p.&&_OUTPUT_col&i._name.;
      %end;
      %else %if &&_OUTPUT_col&i._exp.=  %then %do;
         %if &&_OUTPUT_col&i._input0_table.=&_LEFT. %then %do;
            %let _OUTPUT_col&i._calc = L.&&_OUTPUT_col&i._input0. as &&_OUTPUT_col&i._name.;
         %end;
         %else %if &&_OUTPUT_col&i._input0_table.=&_RIGHT. %then %do;
            %let _OUTPUT_col&i._calc = R.&&_OUTPUT_col&i._input0. as &&_OUTPUT_col&i._name.;
         %end;
         %else %do;
            %let _OUTPUT_col&i._calc = null as &&_OUTPUT_col&i._name.;
         %end;
      %end;
      %if %lowcase(&&_OUTPUT_col&i._name.)=%lowcase(&validFromColumn.) %then %let validFromColumnIndex=&i.;
      %if %lowcase(&&_OUTPUT_col&i._name.)=%lowcase(&validToColumn.) %then %let validToColumnIndex=&i.;
   %end;   

   %if %length(&validFromColumnIndex.)=0 or %length(&validToColumnIndex.)=0 %then %do;
      %put ERROR: Columns &validFromColumn. and &validToColumn. have to be present in the output!;
      %return;
   %end;

   proc sort data=&_LEFT. out=TLJ_Left presorted;
      by &KeyColumns_compbl. &validFromColumn.;
   run;

   %do segment=1 %to %eval(%countObs(TLJ_Left)/&segmentSize.+1);
      %let segmentStart=%eval((&segment.-1)*&segmentSize.+1);
      %let segmentEnd=%eval(&segment.*&segmentSize.);

      %* Determine overlapping periods ;
      proc sql;
         create table TLJ_JoinedPeriods as 
         select    %addPrefix(%str(l.),%quote(&KeyColumns_comma.)),
               l.&validFromColumn. as lvf,
               l.&validToColumn. as lvt,
               r.&validFromColumn. as rvf, 
               r.&validToColumn. as rvt
         from TLJ_Left(firstobs=&segmentStart. obs=&segmentEnd.) l
         left join &_RIGHT. r
            on %unquote(&joinCondition.)
            and not (r.&validFromColumn.>=l.&validToColumn. 
                   or l.&validFromColumn.>=r.&validToColumn.) %* not (separate) = overlapping periods ;
         ;
      quit;


      %* Make a list of points in time ;
      data TLJ_PointsInTime(keep=&KeyColumns. _pit);
         set TLJ_JoinedPeriods;
         length _pit 8;
         format _pit &dateFormat.;

         _pit=lvf; output;
         _pit=lvt; output;
         _pit=rvf; output;
         _pit=rvt; output;
      run;

      proc sort data=TLJ_PointsInTime nodupkey;
         by &KeyColumns. _pit;
      run;


      %* Turn points in time into separate periods ;
      data TLJ_CutPeriods (keep=&KeyColumns. &validFromColumn. &validToColumn.);
         set TLJ_PointsInTime;
         by &KeyColumns.;

         length _prev_pit 8 &validFromColumn. 8 &validToColumn. 8;
         format _prev_pit &dateFormat. &validFromColumn. &dateFormat. &validToColumn. &dateFormat.;

         retain _prev_pit;
            if ^first.&LastKeyColumn. then do;
               &validFromColumn.=_prev_pit;
               &validToColumn.=_pit;
               output;
            end;
         _prev_pit=_pit;
      run;


      %* Join the data back to the cut periods ;
      proc sql;
         create table TLJ_Joined as
         select    %do i=0 %to &_OUTPUT_col_count.-1;
                  &&_OUTPUT_col&i._calc.
                  %if &i.<&_OUTPUT_col_count.-1 %then %do; , %end;
               %end;   
         from TLJ_CutPeriods P
         left join TLJ_Left(firstobs=&segmentStart. obs=&segmentEnd.) L
            on    1=1
               %do i=1 %to &keyColumns_count.;
                  and   L.&&keyColumns&i.=P.&&keyColumns&i.
               %end;
              and   L.&validFromColumn.<=P.&validFromColumn.
            and P.&validFromColumn.<L.&validToColumn.
         left join &_RIGHT. R
            on    %unquote(&joinCondition.)
            and R.&validFromColumn.<=P.&validFromColumn.
            and P.&validFromColumn.<R.&validToColumn.
         where L.&validFromColumn. is not null
            %if &JoinType.=INNER %then %do;
               and R.&validFromColumn. is not null
            %end;
         order by %addPrefix(%str(L.),%quote(&KeyColumns_comma.)), &validFromColumn.
         ;
      quit;

      %if &segment.=1 %then %do;
         data TLJ_JoinedAll;
            set TLJ_Joined;
         run;
      %end; %else %do;
         proc append base=TLJ_JoinedAll data=TLJ_Joined;
         run;
      %end;

   %end;

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
      set TLJ_JoinedAll (rename=(%do i=0 %to &_OUTPUT_col_count.-1; 
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
                  %if %findwi(&validFromColumn. &validToColumn., &&_OUTPUT_col&i._name.)=0 %then %do;
                     and _next_col&i.=&&_OUTPUT_col&i._name.
                  %end;
               %end; and _next_col&validFromColumnIndex.=&validToColumn. then do;
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
         delete TLJ_:;
      run;
   %end;

%mend timelineJoin;
%timelineJoin;
