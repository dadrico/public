/**
 * HIERARCHY SEARCH custom transformation 
 * Used to get information about the ancestors from the hierarchy tree of a table with a child-parent relation
 *
 * Options settings:
 * import hierarchy_search.xml in Code Options
 *
 * Inputs/Outputs settings:
 * [v] Transformation supports inputs (min=1, max=1)
 * [v] Transformation supports outputs (min=1, max=1)
 * [v] Automaticallygenerate delete code for outputs
 * [v] Generate column mapping macros
 *
 * https://github.com/dadrico/
 */

%macro hierarchy_search;

   %do i=0 %to &_OUTPUT_col_count.-1;
      %if &&_OUTPUT_col&i._name. = &childKey. %then %let childKey_col_index = &i.;
      %if &&_OUTPUT_col&i._name. = &parentKey. %then %let parentKey_col_index = &i.;
   %end;

   %* some checks ;
   %if &childKey_col_index. = &parentKey_col_index. %then %do;
      %put ERROR: Child and parent cannot be the same column!;
      %abort cancel;
   %end;
   %if &&_OUTPUT_col&childKey_col_index._length. ^= &&_OUTPUT_col&parentKey_col_index._length. 
      or &&_OUTPUT_col&childKey_col_index._type. ^= &&_OUTPUT_col&parentKey_col_index._type. %then %do;
      %put ERROR: Child and parent columns have to be of the same type and length!;
      %abort cancel;
   %end;

   %* create pure hierarchy table - relations only ;
   proc sql;
      create table _IHS_Hierarchy as
      select distinct
               &childKey. as _child_key,
               &parentKey. as _parent_key
      from &_INPUT.
      where ^missing(&childKey.) and ^missing(&parentKey.)
      order by &childKey., &parentKey.;
   quit;

   %* create a table with the parent data - only the records which keys have children are present here ; 
   data _IHS_Parent_Data(keep=__: _child_key);
      set &_INPUT.;

      length   _child_key _parent_key &&_OUTPUT_col&childKey_col_index._type.&&_OUTPUT_col&childKey_col_index._length.
               _parent_data_char $1000 _parent_data_num 8;

      %* declare a hash to search for a child record for any given record ;
      if _n_=1 then do;
         declare hash h (dataset:'_IHS_Hierarchy');
         h.definekey('_parent_key');
         h.definedata('_child_key'); 
         h.definedone();
      end;

      %* create input variables with __ prefix ; 
      %do i=0 %to &_OUTPUT_col_count.-1;
         %if &&_OUTPUT_col&i._input_count. > 0 %then %do;
            __&&_OUTPUT_col&i._input0. = &&_OUTPUT_col&i._input0.;
         %end;
      %end;

      %* search for a child. Only output if a child is found ;
      _parent_key = &childKey.;
      _found=(h.find()=0);
      if _found then do;
         _child_key = _parent_key;
         output;
      end;

   run;

   %* declare functions (for each function there are 2 macros - n_ for numeric and c_ for character ;
   %macro c_getRootPath();
      _parent_data_char=_root_path;
      _apply=1;
   %mend;

   %macro n_getRootPath();
      %put ERROR: The variable for the root path has to be nummeric!;
   %mend;

   %macro c_getFromRoot(_col);
      if _root then do;
         _parent_data_char=strip(__&_col.);
         _apply=1;
      end;
   %mend;

   %macro n_getFromRoot(_col);
      if _root then do;
         _parent_data_num=__&_col.;
         _apply=1;
      end;
   %mend;

   %macro c_getFromParent(_col);
      if _level=1 then do;
         _parent_data_char=strip(__&_col.);
         _apply=1;
      end;
   %mend;

   %macro n_getFromParent(_col);
      if _level=1 then do;
         _parent_data_num=__&_col.;
         _apply=1;
      end;
   %mend;

   %macro c_getFromAncestorLevel(_col,_lev);
      __testing=10;
      if _level=&_lev. then do;
         __testing=11;
         _parent_data_char=strip(__&_col.);
         _apply=1;
      end;
   %mend;

   %macro n_getFromAncestorLevel(_col,_lev);
      __testing=20; 
      if _level=&_lev. then do;
         __testing=21;
         _parent_data_num=__&_col.;
         _apply=1;
      end;
   %mend;

   %* start the processing of the input ;
   %let errors_ind = 0;
   data &_OUTPUT. (keep=&_keep.);

      set &_INPUT.;

      length   _child_key 
               _parent_key 
               &&_OUTPUT_col&childKey_col_index._type.&&_OUTPUT_col&childKey_col_index._length.
               _root_path $1000
               _parent_data_char $1000 
               _parent_data_num 8;

      %* prepare columns to put the data from the parent-data hash table into ;
      if _n_=1 then do;
         %do i=0 %to &_OUTPUT_col_count.-1;
            %if &&_OUTPUT_col&i._input_count. > 0 %then %do;
               __&&_OUTPUT_col&i._input0. = &&_OUTPUT_col&i._input0.;
               call missing(__&&_OUTPUT_col&i._input0.);
            %end;
         %end;
      end;

      %* define the hash table with the child-parent hierarchy ;
      if _n_=1 then do;
         declare hash h (dataset:'_IHS_Hierarchy', multidata:'yes');
         h.definekey('_child_key');
         h.definedata('_parent_key'); 
         h.definedone();
      end;

      %* define the hash table with the data of all the parents ;
      if _n_=1 then do;
         declare hash pd (dataset:'_IHS_Parent_Data');
         pd.definekey('_child_key');
         pd.definedata(all:'yes'); 
         pd.definedone();
      end;

      _level = 0;
      _root = 0;
      _child_key = &childKey.;
      _root_path = strip(_child_key);

      %* find a parent ;
      _found=(h.find()=0);

      if _found then do;
         do until (_done);
            %* check if the child has more than one parent ;
            _found=(h.find_next()=0);
            if _found then do;
               _root_path = cats(_root_path,'>','[ERROR_multiple_parents]');
               call symput('errors_ind',1);
               _done = 1;
            end;

            if ^_done then do;
               _child_key = _parent_key;
               _root_path = cats(_root_path,'>',_child_key);
               _level = _level+1;

                    %* find the parent of the previously found parent ;
               _found=(h.find()=0);
               if ^_found then do;
                  _root_path = cats(_root_path,'!');
                  _root = 1;
                  _done = 1;
               end;
            end;

            %* get the data from the currently found parent from the parent-data hash table ;
            _found_data=(pd.find()=0);
            if _found_data then do;
               %do i=0 %to &_OUTPUT_col_count.-1;
                        %* iterate through columns and if there is an expression in the mappings, execute the corresponding macro (_n of _c version of it);
                        %* the macro will put the correct value of the parent in the _parent_data_num/char variable and set the _apply flag to 1 ;
                  _apply=0;
                  %if %length(&&_OUTPUT_col&i._exp.)>0 and &&_OUTPUT_col&i._input_count. > 0 %then %do;
                     %if &&_OUTPUT_col&i._type.=$ %then %do;
                        %c_&&_OUTPUT_col&i._exp.;
                        if _apply then &&_OUTPUT_col&i._name.=strip(_parent_data_char);
                     %end;
                     %else %do;
                        %n_&&_OUTPUT_col&i._exp.;
                        if _apply then &&_OUTPUT_col&i._name.=_parent_data_num;
                     %end;
                  %end;
               %end;
            end;
            %* if the parent data is not found it means that the parent is mentioned in the parent column, but it does not have its own record in the input ;
            else do;
               _root_path = cats(_root_path,'[MISSING]');
            end;
            
         end; %* / do until (_done) ;
      end; %* / if _found ;
      %* if there is no parent of this record in the hierarchy then this is a root record ;
      else do;
         _root_path = cats(_root_path,'!');
         _root = 1;
         %do i=0 %to &_OUTPUT_col_count.-1;
            %if &&_OUTPUT_col&i._input_count. > 0 %then %do;
               __&&_OUTPUT_col&i._input0. = &&_OUTPUT_col&i._input0.;
            %end;
         %end;
      end;

      %* run the functions once more - this bit can probably be improved so that this code is not repeated ;
      %do i=0 %to &_OUTPUT_col_count.-1;
         _apply = 0;
         %if %length(&&_OUTPUT_col&i._exp.)=0 %then %do;
            &&_OUTPUT_col&i._name. = &&_OUTPUT_col&i._input0.;
         %end;
         %else %do;
            %if &&_OUTPUT_col&i._type.=$ %then %do;
               %c_&&_OUTPUT_col&i._exp.;
               if _apply then &&_OUTPUT_col&i._name.=strip(_parent_data_char);
            %end;
            %else %do;
               %n_&&_OUTPUT_col&i._exp.;
               if _apply then &&_OUTPUT_col&i._name.=_parent_data_num;
            %end;
         %end;
      %end;

      output;
   run;
%mend hierarchy_search;
%hierarchy_search;
