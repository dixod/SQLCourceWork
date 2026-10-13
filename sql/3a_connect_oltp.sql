\set ON_ERROR_STOP on
\getenv source_password PGPASSWORD

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE SCHEMA IF NOT EXISTS source_oltp;

CREATE SERVER IF NOT EXISTS coursework_source
FOREIGN DATA WRAPPER postgres_fdw
OPTIONS (host :'source_host', port :'source_port', dbname :'oltp_db');

ALTER SERVER coursework_source OPTIONS (
    SET host :'source_host', SET port :'source_port', SET dbname :'oltp_db'
);

CREATE USER MAPPING IF NOT EXISTS FOR CURRENT_USER
SERVER coursework_source
OPTIONS (user :'source_user', password :'source_password');

ALTER USER MAPPING FOR CURRENT_USER SERVER coursework_source
OPTIONS (SET user :'source_user', SET password :'source_password');

SELECT format(
    'IMPORT FOREIGN SCHEMA oltp LIMIT TO (%s) FROM SERVER coursework_source INTO source_oltp',
    string_agg(quote_ident(table_name), ', ')
)
FROM (VALUES ('countries'), ('cities'), ('data_quality_levels'),
             ('cost_categories'), ('cost_items'), ('city_cost_values')) AS expected(table_name)
WHERE to_regclass('source_oltp.' || table_name) IS NULL
HAVING COUNT(*) > 0
\gexec
