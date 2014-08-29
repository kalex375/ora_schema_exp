--Drop all the objects and PURGE RECYCLEBIN;

declare
  l_string  varchar2(4000);
  l_execute boolean := true;
begin
  for i in (select distinct (case
                              when object_type = 'PACKAGE BODY' then
                               'PACKAGE'
                              else
                               object_type
                            end) object_type,
                            object_name
            from   user_objects
            where  object_type in ('SEQUENCE',
                                   'VIEW',
                                   'SYNONYM',
                                   'PROCEDURE',
                                   'FUNCTION',
                                   'PACKAGE',
                                   'JAVA SOURCE',
                                   --'JAVA CLASS',
                                   'TYPE',
                                   'JOB',
                                   'SCHEDULE',
                                   'PROGRAM',
                                   'JAVA RESOURCE',
                                   'CHAIN',
                                   'TABLE')
            order  by object_type,
                      object_name)
  loop
    l_string := 'DROP ' || i.object_type || ' ' || i.object_name;
  
    case
      when i.object_type = 'TABLE' then
        l_string := l_string || ' CASCADE CONSTRAINTS';
      when i.object_type = 'TYPE' then
        l_string := l_string || ' FORCE';
      when i.object_type = 'JOB' then
        l_execute := false;
      
        DBMS_SCHEDULER.drop_job(job_name => '"' || i.object_name || '"',
                                force    => true);
      when i.object_type = 'SCHEDULE' then
        l_execute := false;
      
        DBMS_SCHEDULER.drop_schedule(schedule_name => '"' || i.object_name || '"',
                                     force         => true);
      when i.object_type = 'PROGRAM' then
        l_execute := false;
      
        DBMS_SCHEDULER.drop_program(program_name => '"' || i.object_name || '"',
                                    force        => true);
      when i.object_type = 'CHAIN' then
        l_execute := false;
      
        DBMS_SCHEDULER.drop_chain(chain_name => '"' || i.object_name || '"',
                                  force      => true);
      else
        null;
    end case;
  
    if l_execute then
      begin
        execute immediate l_string;
        l_string := null;
     exception when others then   
        dbms_output.put_line('Cant execute:'||l_string);
      end;
    else
      l_execute := true;
    end if;
  end loop;
  execute immediate 'PURGE RECYCLEBIN';
end;
/
