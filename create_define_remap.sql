BEGIN
  select listagg(t.tablespace_name || '=~~' || t.tablespace_name, ';') within group(order by t.tablespace_name)
  into   :TABLESPACE_REMAP
  from   (select distinct t.tablespace_name from user_tables t where t.tablespace_name is not null
          union
          select distinct t.tablespace_name from user_tab_partitions t where t.tablespace_name is not null
          union
          select distinct t.tablespace_name from user_tab_subpartitions t where  t.tablespace_name is not null
          union
          select distinct t.tablespace_name from   user_indexes t where  t.tablespace_name is not null
          union
          select distinct t.tablespace_name from   user_ind_partitions t where  t.tablespace_name is not null
          union
          select distinct t.tablespace_name from   user_ind_subpartitions t where  t.tablespace_name is not null) t
  where tablespace_name<>'SYSTEM';
END;
/

BEGIN
  select
    listagg(t.table_owner || '=~~' || t.table_owner, ';') within group(order by t.table_owner)
  into :SYNONYM_OWNER_REMAP
  from 
    (select distinct t.table_owner from user_synonyms t where t.table_owner is not null ) t;
END;
/

spool 'exp_schema\&&OWNER\defines.sql'
prompt /*-----------------------------------*/
prompt /*  DEFINE SCHEMA OWNER              */
prompt /*-----------------------------------*/
prompt define SCHEMA_OWNER = ~~_USER


prompt /*-----------------------------------*/
prompt /*  DEFINE TABLESAPCE                */
prompt /*-----------------------------------*/
  
  select rpad('define '||t.tablespace_name,31,' ') || '=''' || t.tablespace_name||''''
  from   (select distinct t.tablespace_name from user_tables t where t.tablespace_name is not null
          union
          select distinct t.tablespace_name from user_tab_partitions t where t.tablespace_name is not null
          union
          select distinct t.tablespace_name from user_tab_subpartitions t where  t.tablespace_name is not null
          union
          select distinct t.tablespace_name from   user_indexes t where  t.tablespace_name is not null
          union
          select distinct t.tablespace_name from   user_ind_partitions t where  t.tablespace_name is not null
          union
          select distinct t.tablespace_name from   user_ind_subpartitions t where  t.tablespace_name is not null) t;

prompt /*-----------------------------------*/
prompt /* DEFINE SYNONYM TABLE OWNER        */
prompt /*-----------------------------------*/

  select
    rpad('define '||t.table_owner,31,' ') || '=''' || t.table_owner||''''
  from 
    (select distinct t.table_owner from user_synonyms t where t.table_owner is not null ) t;
		  
spool off		  