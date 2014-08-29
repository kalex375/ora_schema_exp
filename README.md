Script to Export Database Schema
==============

Script to Export Database Schema using DBMS_METADATA. It very useful if don't have permission on DATA PUMP, or you want get DDL for all objects

Usage

`sql> conn schema_name/schema_pwd@ORACL

sql> @exp.sql`

Script to Export Database Schema using DBMS_METADATA. It very useful if don't have permission on DATA PUMP, or you want get DDL for all objects
After that script will be generate DDL for each object type in separate folder exp_schema\schema_name\TABLE | VIEWS| PROCEDURE etc.
Tablespace name, owner and sysnonym table owner replaced to define in defines.sql where you can set new values before import.

For import schema run exp_schema\schema_name\BuildAll.sql script on target schema. 

