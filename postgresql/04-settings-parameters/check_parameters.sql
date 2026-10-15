select name, setting, sourcefile, source from pg_catalog.pg_settings where sourcefile;
 
select name, setting, sourcefile, source from pg_catalog.pg_settings where sourcefile is not null;
