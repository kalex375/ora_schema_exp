-- Created on 08/08/2013 by OKRAVCHENKO 
declare 
  --------------------------------------------------------------
  --INIT PARAMS
  --------------------------------------------------------------
  p_object_type  varchar2(32000)     :=  :OBJECT_TYPE;
  p_object_name  varchar2(32000)     :=  :OBJECT_NAME;
  tablespace_remap varchar2(2000)    :=  :TABLESPACE_REMAP;
  synonym_owner_remap varchar2(2000) :=  :SYNONYM_OWNER_REMAP;
  p_tmp  clob;
  
  
  --------------------------------------------------------------
  --CONFIG
  --------------------------------------------------------------
  TABLE_IN_ONE_FILE   varchar2(1)   := 'F'; --T-true/F-false            
  
  PACKAGE_TYPE_IN_ONE_FILE varchar2(1)   := 'F'; --T-true/F-false
  
  NEW_SCHEMA  varchar(2000) := '~~SCHEMA_OWNER';
  
  --------------------------------------------------------------

  --Object types
  c_obj_all_grants       constant varchar2(30) := 'ALL_GRANTS';
  c_obj_all_pub_synonyms constant varchar2(30) := 'ALL_PUBLIC_SYNONYMS';
  c_obj_comment          constant varchar2(30) := 'COMMENT';
  c_obj_constraint       constant varchar2(30) := 'CONSTRAINT';
  c_obj_ref_constraint   constant varchar2(30) := 'REF_CONSTRAINT';
  c_obj_index            constant varchar2(30) := 'INDEX';
  c_obj_db_link          constant varchar2(30) := 'DB_LINK';
  c_obj_function         constant varchar2(30) := 'FUNCTION';
  c_obj_grant            constant varchar2(30) := 'GRANT';
  c_obj_mat_view         constant varchar2(30) := 'MATERIALIZED VIEW';
  c_obj_package          constant varchar2(30) := 'PACKAGE';
  c_obj_package_body     constant varchar2(30) := 'PACKAGE BODY';
  c_obj_procedure        constant varchar2(30) := 'PROCEDURE';
  c_obj_public_synonym   constant varchar2(30) := 'PUBLIC SYNONYM';
  c_obj_sequence         constant varchar2(30) := 'SEQUENCE';
  c_obj_synonym          constant varchar2(30) := 'SYNONYM';
  c_obj_table            constant varchar2(30) := 'TABLE';
  c_obj_table_constr     constant varchar2(30) := 'TABLE_CONSTRAINTS';
  c_obj_trigger          constant varchar2(30) := 'TRIGGER';
  c_obj_type             constant varchar2(30) := 'TYPE';
  c_obj_type_body        constant varchar2(30) := 'TYPE BODY';
  c_obj_view             constant varchar2(30) := 'VIEW';
  c_obj_java_src         constant varchar2(30) := 'JAVA_SOURCE';
  
  
  --------------------------------------------------------------
  function is_empty(p_value in clob) return boolean is
  begin
    if p_value is null or length(p_value) = 0 then
      return true;
    else
      return false;
    end if;
  end is_empty;  


  --------------------------------------------------------------
  function get_owner_remap(p_object clob) return clob  
  is
    v_result clob;
  begin
    v_result := p_object;
    for c_list_remap in (
                         select 
                           replace(regexp_substr(v.param_value , '(^|;)[^=]+', 1, level), ';') owner,
                           regexp_substr(v.param_value , '(\~)[^;$]+', 1, level) remap_owner       
                         from 
                           (select 
                              SYNONYM_OWNER_REMAP param_value
                            from 
                              dual) v
                          connect by level <= regexp_count(v.param_value, '=')
                         )
    loop
      v_result := replace(v_result, 'FOR "'||c_list_remap.owner, 'FOR "'||c_list_remap.remap_owner); 
    end loop;   
    
    return  v_result;                     
  end;  

  --------------------------------------------------------------  
  function get_schema_name_removed(p_object clob) return clob is
    v_schema varchar2(240);
    v_new_schema varchar2(240);
  begin
    v_schema := chr(34) || user || chr(34) || '.';
  
    if NEW_SCHEMA is not null then
      v_new_schema := chr(34) || NEW_SCHEMA || chr(34) || '.';
    end if;
      
    return replace(p_object, v_schema, v_new_schema);
  end get_schema_name_removed;

  --------------------------------------------------------------  
 function get_java_source(p_object_name in varchar2) return clob is
   b clob;
   c clob;
 begin
   dbms_lob.createtemporary(b, false);
   dbms_lob.createtemporary(c, false);   
   dbms_java.export_source(dbms_java.longname(p_object_name), b);
   dbms_lob.append(c,'CREATE OR REPLACE AND COMPILE JAVA SOURCE NAMED "'||NEW_SCHEMA||'"."'||p_object_name||'" AS '||chr(10));
   dbms_lob.append(c,b);   
   dbms_lob.append(c,chr(10)||'/');
   return c;
 end;

 --------------------------------------------------------------      
 function resolve_metadata_type_pkg(p_object_type in varchar2) return varchar2
 is 
 begin
   if p_object_type = 'PACKAGE BODY' then 
     return 'PACKAGE';
   elsif p_object_type = 'TYPE BODY' then 
     return 'TYPE';
   else 
     return p_object_type;
   end if;
 end;  
 
  --------------------------------------------------------------    
  function get_by_dbms_metadata(p_object_type in varchar2,
                                p_object_name in varchar2,
                                p_object_ddl  in varchar2) return clob is
    v_buffer clob;
    v_result clob;
    v_handle number;
    
    procedure init_dbms_metadata is
      v_modify_handle number;
      v_ddl_handle    number;
    begin
      v_modify_handle := dbms_metadata.add_transform(v_handle, 'MODIFY');
      v_ddl_handle    := dbms_metadata.add_transform(v_handle, 'DDL');
      dbms_metadata.set_transform_param(v_ddl_handle, 'SQLTERMINATOR', true);

      --dbms_metadata.set_transform_param(v_ddl_handle,'PRETTY',FALSE);

      if p_object_type = c_obj_table then
        dbms_metadata.set_transform_param(v_ddl_handle, 'CONSTRAINTS',false);
        dbms_metadata.set_transform_param(v_ddl_handle, 'REF_CONSTRAINTS',false);
      end if;
      
      if p_object_type in (c_obj_package_body, c_obj_package, c_obj_type, c_obj_type_body) and PACKAGE_TYPE_IN_ONE_FILE = 'F' then 
        
        if p_object_type in (c_obj_package_body,c_obj_type_body) then 
          dbms_metadata.set_transform_param(v_ddl_handle, 'SPECIFICATION',false);
        else
          dbms_metadata.set_transform_param(v_ddl_handle, 'BODY',false);
        end if;
          
      end if;

      if p_object_type in (c_obj_table, c_obj_index, c_obj_constraint) then
  
        --dbms_metadata.set_transform_param(v_ddl_handle,'SEGMENT_ATTRIBUTES',false);
        dbms_metadata.set_transform_param(v_ddl_handle, 'STORAGE', false);
  
        for v_tbs_remap in (select 
                              replace(regexp_substr(v.param_value , '(^|;)[^=]+', 1, level), ';') tablespace_name,
                              regexp_substr(v.param_value , '(\~)[^;$]+', 1, level) remap_tablespace_name
                            from 
                             (select 
                                TABLESPACE_REMAP param_value
                              from 
                                dual) v
                            connect by level <= regexp_count(v.param_value, '=')) 
        loop
          dbms_metadata.set_remap_param(v_modify_handle, 'REMAP_TABLESPACE',
                                        v_tbs_remap.tablespace_name,
                                        v_tbs_remap.remap_tablespace_name);
        end loop;
      end if;
      
      dbms_metadata.set_remap_param(v_modify_handle, 'REMAP_SCHEMA',
                                    user,
                                    NEW_SCHEMA);
    end init_dbms_metadata;
    
  begin
    dbms_lob.createtemporary(v_result, true);
    v_handle := dbms_metadata.open(resolve_metadata_type_pkg(p_object_type));
    if p_object_ddl = 'DDL' then
      dbms_metadata.set_filter(v_handle, 'NAME', p_object_name);
    elsif p_object_ddl = 'DEPENDENT_DDL' then
      dbms_metadata.set_filter(v_handle, 'BASE_OBJECT_NAME', p_object_name);
      if p_object_type in (c_obj_index) then 
        dbms_metadata.set_filter(v_handle, 'NAME_EXPR','not like ''SYS_IL%''');
      end if;  
    end if;
    init_dbms_metadata;
    loop
      v_buffer := dbms_metadata.fetch_clob(v_handle);
      if v_buffer is null then
        exit;
      else
        dbms_lob.append(v_result, v_buffer);
      end if;
    end loop;
    return v_result;
  end get_by_dbms_metadata;
 

 --------------------------------------------------------------      
 function resolve_metadata_type(p_object_type in varchar2) return varchar2
 is 
 begin
   if p_object_type = 'DATABASE LINK' then 
     return 'DB_LINK';
   elsif p_object_type = 'JAVA SOURCE' then 
     return 'JAVA_SOURCE';
   else 
     return p_object_type;
   end if;
 end;   
 --------------------------------------------------------------      
 function get_table(p_object_name in varchar2) return clob
 is
    v_prompt   varchar2(240);
    v_comments clob;
    v_result   clob;
  begin
    dbms_lob.createtemporary(v_result, true);
    dbms_lob.append(v_result, get_by_dbms_metadata(c_obj_table, p_object_name, 'DDL'));
    
    --v_comments := get_by_dbms_metadata(c_obj_comment, p_object_name, 'DEPENDENT_DDL');
    --if not is_empty(v_comments) then
    --  dbms_lob.append(v_result, v_comments);
    --end if;
    return v_result; 
 end;

 --------------------------------------------------------------      
 function get_object_ddl(p_object_type in varchar2, p_object_name in varchar2) return clob is
    v_object_type varchar2(240);
  begin
   
   v_object_type := resolve_metadata_type(p_object_type);
     
   if v_object_type in (c_obj_table) then 
     
     return replace(replace(get_table(p_object_name),'SEGMENT CREATION DEFERRED',null),'SEGMENT CREATION IMMEDIATE',null);
     
   elsif v_object_type in (c_obj_index,          
                           c_obj_constraint,
                           c_obj_ref_constraint,
                           c_obj_comment) then   

     return get_by_dbms_metadata(v_object_type,p_object_name,'DEPENDENT_DDL');
                                      
   elsif v_object_type in ( c_obj_package_body,
                            c_obj_package,
                            c_obj_type,
                            c_obj_type_body)  then  
                            
     return get_by_dbms_metadata(v_object_type,p_object_name,'DDL');                              

   elsif v_object_type in ( c_obj_synonym,
                            c_obj_public_synonym) then 

     return get_owner_remap(get_by_dbms_metadata(v_object_type,p_object_name,'DDL'));  
                                 
   elsif v_object_type in ( c_obj_db_link,   
                            c_obj_sequence, 
                            c_obj_type,     
                            c_obj_view,
                            c_obj_function,  
                            c_obj_procedure, 
                            c_obj_trigger,   
                            c_obj_grant,     
                            c_obj_mat_view) then
                            
     return get_by_dbms_metadata(v_object_type,p_object_name,'DDL');  

   elsif v_object_type in (c_obj_java_src) then
   
     return get_java_source(p_object_name);                            
   else 
     raise_application_error(-20001, 'Object type not supported : '|| p_object_type);  
   end if;  
   
  end get_object_ddl;  
  
begin
  :VCLOB := get_object_ddl(p_object_type,p_object_name);
end;
/
