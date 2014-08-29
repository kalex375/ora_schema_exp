set def '&'
set long 200000
set lines 180
set trimspool on
set heading off
set feedback off
set pages 0
set verify off
set echo off
set timing off
set LINESIZE 5000
set TERMOUT OFF
column c format a500
set serveroutput on
define OWNER = &&_USER

var OBJECT_TYPE varchar2(30)
var OBJECT_NAME varchar2(30)
var TABLESPACE_REMAP varchar2(2000)
var SYNONYM_OWNER_REMAP varchar2(2000)
var vclob clob

begin
  dbms_output.enable(null);
end;
/

host rmdir /s /q "exp_schema\&&OWNER"
host mkdir "exp_schema\&&OWNER"

-----------------------------------------------
--Define remap params
-----------------------------------------------
@create_define_remap.sql

-----------------------------------------------
--create tmp_create_dir
-----------------------------------------------
spool 'exp_schema\&&OWNER\tmp_create_dir.tmp'

declare
  cursor cur 
  is 
    with tbl_object as (
     select 'TABLE' object_type, t.table_name object_name from user_tables t union
     select distinct 'INDEX' object_type, i.table_name from user_indexes i union
     select distinct 'CONSTRAINT' object_type, r.table_name from user_constraints r where r.constraint_type <> 'R' union
     select 'COMMENT' object_type, t.table_name  from user_tables t union
     select distinct 'REF_CONSTRAINT' object_type, r.table_name from user_constraints r where r.constraint_type = 'R'
   )
   select distinct
	   'host rmdir /s /q "exp_schema\&&OWNER\'||o.OBJECT_TYPE||'";' a,
     'host mkdir "exp_schema\&&OWNER\'||o.OBJECT_TYPE||'";' b
    from 
       (select
         o.OBJECT_NAME,
         o.OBJECT_TYPE
       from  
         user_objects o 
       where 
         o.OBJECT_TYPE not in ('INDEX',
                               'TABLE SUBPARTITION',
                               'TABLE PARTITION',
                               'SCHEDULER GROUP',
                               'SCHEDULE',
                               'PROGRAM',
                               'LOB',
                               'JOB CLASS',
                               'JAVA CLASS',  
                               'JAVA DATA',
                               'JAVA RESOURCE',
                               'INDEXTYPE',
                               'INDEX SUBPARTITION',
                               'INDEX PARTITION',
                               'EVALUATION CONTEXT',
                               'EDITION',
                               'DIRECTORY',
                               'DESTINATION',
                               'CONSUMER GROUP',
                               'CLUSTER',
                               'TABLE',
                               'DATABASE LINK')
      union 
      select 
        t.OBJECT_NAME,
        t.object_type 
      from 
        tbl_object t) o;
begin
  for cur_rec in cur
  loop
    dbms_output.put_line(cur_rec.a);
    dbms_output.put_line(cur_rec.b);
  end loop;
end;
/

------------------------------------------------
--create tmp_get_sql.tmp
------------------------------------------------	
spool 'exp_schema\&&OWNER\tmp_get_sql.tmp'

prompt set feedback off
prompt set heading off
prompt set linesize 1000
prompt set trimspool on
prompt set verify off
prompt SET LONG 1000000 LONGC 100000  LIN 32000 pages 0
prompt set def '^'

declare
  cursor cur 
  is 
    with tbl_object as (
     select 'TABLE' object_type, t.table_name object_name from user_tables t union
     select distinct 'INDEX' object_type, i.table_name from user_indexes i union
     select distinct 'CONSTRAINT' object_type, r.table_name from user_constraints r where r.constraint_type <> 'R' union
     select 'COMMENT' object_type, t.table_name  from user_tables t union
     select distinct 'REF_CONSTRAINT' object_type, r.table_name from user_constraints r where r.constraint_type = 'R'
  )
   select 
      'prompt /*---------------------------------------------*/' a0,
      'prompt OBJECT TYPE:'||o.OBJECT_TYPE a00,
      'prompt /*---------------------------------------------*/' a000,      
      'prompt OBJECT TYPE:'||o.OBJECT_TYPE||', OBJECT NAME:'||o.OBJECT_NAME a1,
      'exec :OBJECT_TYPE := '''||o.OBJECT_TYPE||'''' a2,
      'exec :OBJECT_NAME := '''||o.OBJECT_NAME||'''' a3,
      '@exp_object.sql' a4,
      'set termout off' a5,
      'spool "exp_schema\&&OWNER\'||o.OBJECT_TYPE||'\'||(o.object_name)||'.sql'||'"; ' a6,
      'print vclob' a7,
      'spool off' a8,
      'set termout on' a9    
    from 
       (select
         o.OBJECT_NAME,
         o.OBJECT_TYPE
       from  
         user_objects o 
       where 
         o.OBJECT_TYPE not in ('INDEX',
                               'TABLE SUBPARTITION',
                               'TABLE PARTITION',
                               'SCHEDULER GROUP',
                               'SCHEDULE',
                               'PROGRAM',
                               'LOB',
                               'JOB CLASS',
                               'JAVA CLASS',  
                               'JAVA DATA',
                               'JAVA RESOURCE',
                               'INDEXTYPE',
                               'INDEX SUBPARTITION',
                               'INDEX PARTITION',
                               'EVALUATION CONTEXT',
                               'EDITION',
                               'DIRECTORY',
                               'DESTINATION',
                               'CONSUMER GROUP',
                               'CLUSTER',
                               'TABLE',
                               'DATABASE LINK')
      union all
      select 
        t.OBJECT_NAME,
        t.object_type 
      from 
        tbl_object t) o    
      order by  decode(o.OBJECT_TYPE,'TABLE','1','INDEX','2','CONSTRAINT','3','REF_CONSTRAINT',4,o.OBJECT_TYPE), OBJECT_NAME;
      
  l_prev_type varchar2(2000) := '-----';    
begin
  for cur_rec in cur
  loop
  
    dbms_output.PUT_LINE('------------------------------------------------');	
      	        
    if cur_rec.a00<>l_prev_type then 
    	dbms_output.PUT_LINE(cur_rec.a0);
    	dbms_output.PUT_LINE(cur_rec.a00);
    	dbms_output.PUT_LINE(cur_rec.a000);                
      l_prev_type:=cur_rec.a00;
    end if;

  	dbms_output.PUT_LINE(cur_rec.a1);
    dbms_output.PUT_LINE(cur_rec.a2);
    dbms_output.PUT_LINE(cur_rec.a3);      
    dbms_output.PUT_LINE(cur_rec.a4); 
    dbms_output.PUT_LINE(cur_rec.a5);            
    dbms_output.PUT_LINE(cur_rec.a6);
    dbms_output.PUT_LINE(cur_rec.a7);
    dbms_output.PUT_LINE(cur_rec.a8);
    dbms_output.PUT_LINE(cur_rec.a9);        
  end loop;
end;
/
prompt set heading on
prompt set termout on
prompt set linesize 100
spool off

------------------------------------------------
--create buildAll.sql
------------------------------------------------
spool 'exp_schema\&&OWNER\buildAll.sql';

prompt set linesize 100
prompt set echo off
prompt set termout on
prompt set feedback on
prompt set autoprint off
prompt set lines 999
prompt set pages 100
prompt set trims on
prompt set define on
prompt set def '~'
prompt set sqlblanklines on
prompt set verify off
prompt set serverout on size 1000000

declare
  cursor cur 
  is 
  with tbl_object as (
     select 'TABLE' object_type, t.table_name object_name from user_tables t union
     select distinct 'INDEX' object_type, i.table_name from user_indexes i union
     select distinct 'CONSTRAINT' object_type, r.table_name from user_constraints r where r.constraint_type <> 'R' union
     select 'COMMENT' object_type, t.table_name  from user_tables t union
     select distinct 'REF_CONSTRAINT' object_type, r.table_name from user_constraints r where r.constraint_type = 'R'
  )
   select 
     o.object_type,
     o.OBJECT_NAME, 
     '@".\'||o.OBJECT_TYPE||'\'||(o.object_name)||'.sql'||'"' a
    from 
       (select
         o.OBJECT_NAME,
         o.OBJECT_TYPE
       from  
         user_objects o 
       where 
         o.OBJECT_TYPE not in ('INDEX',
                               'TABLE SUBPARTITION',
                               'TABLE PARTITION',
                               'SCHEDULER GROUP',
                               'SCHEDULE',
                               'PROGRAM',
                               'LOB',
                               'JOB CLASS',
                               'JAVA CLASS',  
                               'JAVA DATA',
                               'JAVA RESOURCE',
                               'INDEXTYPE',
                               'INDEX SUBPARTITION',
                               'INDEX PARTITION',
                               'EVALUATION CONTEXT',
                               'EDITION',
                               'DIRECTORY',
                               'DESTINATION',
                               'CONSUMER GROUP',
                               'CLUSTER',
                               'TABLE',
                               'DATABASE LINK')
      union 
      select 
        t.OBJECT_NAME,
        t.object_type 
      from 
        tbl_object t) o    
      order by  decode(o.OBJECT_TYPE,'TABLE','1','INDEX','2','CONSTRAINT','3','REF_CONSTRAINT',4,o.OBJECT_TYPE), OBJECT_NAME;
      
  l_prev_type varchar2(30):='------';    
begin
  dbms_output.enable(null);
  dbms_output.put_line('@defines.sql');
  dbms_output.put_line('spool "buildAll'||'.log'||'"; ');

  for cur_rec in cur
  loop
  	dbms_output.put_line('prompt /*---------------------------------------------*/');
  	dbms_output.put_line('prompt OBJECT TYPE:'||cur_rec.OBJECT_TYPE);
  	dbms_output.put_line('prompt OBJECT NAME:'||cur_rec.OBJECT_NAME);
  	dbms_output.put_line('prompt /*---------------------------------------------*/');
  	dbms_output.put_line(cur_rec.a);
    
    l_prev_type := cur_rec.object_type;
  end loop;

  dbms_output.put_line('spool off');
end;
/  

prompt prompt =======================
prompt prompt Rebuilding schema ... 
prompt prompt =======================
prompt exec dbms_utility.compile_schema(schema=>user, compile_all=>false);

spool off
set feedback on
set heading on
set termout on
set linesize 100

@'exp_schema\&&OWNER\tmp_create_dir.tmp';
@'exp_schema\&&OWNER\tmp_get_sql.tmp';
/
--exit;
