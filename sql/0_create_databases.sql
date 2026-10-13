\set ON_ERROR_STOP on

\if :{?oltp_db}
\else
\set oltp_db coursework_oltp
\endif

\if :{?olap_db}
\else
\set olap_db coursework_olap
\endif

SELECT format('CREATE DATABASE %I', :'oltp_db')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'oltp_db')
\gexec

SELECT format('CREATE DATABASE %I', :'olap_db')
WHERE NOT EXISTS (SELECT 1 FROM pg_database WHERE datname = :'olap_db')
\gexec
