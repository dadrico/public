/**
 * ONE RECORD custom transformation
 * Creates a table with one record using the entries in expressions
 * Options settings:
 * No options
 * Inputs/Outputs settings:
 * [ ] Transformation supports inputs
 * [v] Transformation supports outputs (min=1, max=1)
 * [v] Automaticallygenerate delete code for outputs
 * [v] Generate column mapping macros
 *
 * https://github.com/dadrico/
 */

%macro one_record();

   data &_OUTPUT.;
      %do i=0 %to &_OUTPUT_col_count.-1;
         length &&_OUTPUT_col&i._name. &&_OUTPUT_col&i._type.&&_OUTPUT_col&i._length.;
         format &&_OUTPUT_col&i._name. &&_OUTPUT_col&i._format.;
         %if %length(&&_OUTPUT_col&i._exp.)=0 %then %do;
            %if &&_OUTPUT_col&i._type.=$ %then %do;
               &&_OUTPUT_col&i._name.='';
            %end;
            %else %do;
               &&_OUTPUT_col&i._name.=.;
            %end;
         %end;
         %else %do;
            &&_OUTPUT_col&i._name.=&&_OUTPUT_col&i._exp.;
         %end;
      %end;
   run;

%mend one_record;

%one_record();