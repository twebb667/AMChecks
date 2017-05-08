--------------------------------------------------------
--  File created - Monday-March-27-2017   
--------------------------------------------------------
--
-- N.B. Please ensure the database exists (ofc) but also that all
-- amchecks users also exist.
--
-- Edit this file to correct passwords for db_links etc. before
-- running this.

--
-- Note that some tables here are not currently being used
-- ..but may be one day! e.g. AM_PARAMETER, AM_ALERT,
-- AM_ALERT_HISTORY and AM_SCRIPT_SET
--
--------------------------------------------------------
--  DDL for DB Link RMAN1
--------------------------------------------------------

  CREATE DATABASE LINK RMAN1
   CONNECT TO RMAN IDENTIFIED BY change_this
   USING 'RMAN_TNS_ALIAS';

--------------------------------------------------------
-- Oracle directories
--------------------------------------------------------

-- correct the full path as necessary.

CREATE OR REPLACE DIRECTORY amcheck_dir AS '/home/oracle/amchecks/external_tables';

GRANT ALL ON DIRECTORY amcheck_dir TO amu;

-- correct the full path as necessary.

CREATE OR REPLACE DIRECTORY amcheck_temp AS '/tmp/amchecks';

GRANT ALL ON DIRECTORY amcheck_temp TO amu;



--------------------------------------------------------
--  DDL for Table AM_ALERT
--------------------------------------------------------

  CREATE TABLE AMO.AM_ALERT 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	ALERT_CREATED DATE DEFAULT systimestamp, 
	NOTES VARCHAR2(2000 BYTE)
   );

  GRANT SELECT ON AMO.AM_ALERT TO AMU;
--------------------------------------------------------
--  DDL for Table AM_ALERT_HISTORY
--------------------------------------------------------

  CREATE TABLE AMO.AM_ALERT_HISTORY 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	ALERT_CREATED DATE, 
	ALERT_CLOSED DATE, 
	NOTES VARCHAR2(2000 BYTE)
   );

  GRANT SELECT ON AMO.AM_ALERT_HISTORY TO AMU;
--------------------------------------------------------
--  DDL for Table AM_ALL_OS_SPACE_LOAD
--------------------------------------------------------

  CREATE TABLE AMO.AM_ALL_OS_SPACE_LOAD 
   (	SERVER VARCHAR2(30 CHAR), 
	FILESYSTEM VARCHAR2(200 CHAR), 
	SIZEK NUMBER(10,0), 
	USEDK NUMBER(10,0), 
	AVAILK NUMBER(10,0), 
	PCTUSED NUMBER(3,0), 
	MOUNTPOINT VARCHAR2(200 CHAR), 
	DF_DOW VARCHAR2(10 CHAR), 
	DF_TIMESTAMP VARCHAR2(40 CHAR)
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
             SKIP 0 FIELDS TERMINATED BY ', ' MISSING FIELD VALUES ARE NULL
          )
      LOCATION
       ( AMCHECK_DIR:'am_all_os_space_load.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.AM_ALL_OS_SPACE_LOAD TO AMU;

--------------------------------------------------------
--  DDL for Table AM_DATABASE
--------------------------------------------------------

  CREATE TABLE AMO.AM_DATABASE 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	SERVER VARCHAR2(100 CHAR), 
	PRODUCTION_IND CHAR(1 BYTE) DEFAULT 'N', 
	TALLYMAN_IND CHAR(1 BYTE), 
	LICENSE_TYPE VARCHAR2(3 BYTE), 
	SUPPORT_LEVEL NUMBER(2,0), 
	COMMENTS VARCHAR2(4000 BYTE), 
	OS_CHECKS_IND CHAR(1 CHAR) DEFAULT 'N', 
	DEFUNCT1 VARCHAR2(100 CHAR), 
	RUN_ORDER NUMBER DEFAULT 50, 
	MAXIMO_IND CHAR(1 CHAR) DEFAULT 'N', 
	DBID NUMBER, 
	ADHOC_IND CHAR(1 CHAR)
   );

   COMMENT ON COLUMN AMO.AM_DATABASE.DATABASE_NAME IS 'Unique Identifier - the entry used to tnsping';
   COMMENT ON COLUMN AMO.AM_DATABASE.LICENSE_TYPE IS 'Enterprise Edition Standard Edition and other flavours';
   COMMENT ON COLUMN AMO.AM_DATABASE.SUPPORT_LEVEL IS 'Number used to represent importance eg GOLD SILVER BRONZE or SLA value';
   COMMENT ON COLUMN AMO.AM_DATABASE.COMMENTS IS 'Notes relating to the database';
   COMMENT ON COLUMN AMO.AM_DATABASE.OS_CHECKS_IND IS 'Run OS Space checks from this database';
   COMMENT ON COLUMN AMO.AM_DATABASE.DEFUNCT1 IS 'formerly physical_server but now on am_server';
   COMMENT ON TABLE AMO.AM_DATABASE  IS 'List of all databases known to the morning checks system';

  GRANT DELETE ON AMO.AM_DATABASE TO AMU;
  GRANT INSERT ON AMO.AM_DATABASE TO AMU;
  GRANT SELECT ON AMO.AM_DATABASE TO AMU;
  GRANT UPDATE ON AMO.AM_DATABASE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_METRIC_HIST
--------------------------------------------------------

  CREATE TABLE AMO.AM_METRIC_HIST 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	SERVER VARCHAR2(30 CHAR), 
	SPACE_TIME DATE, 
	METRIC VARCHAR2(50 CHAR), 
	VALUE NUMBER, 
	 CONSTRAINT PK_AM_METRIC_HIST PRIMARY KEY (DATABASE_NAME, SERVER, METRIC, SPACE_TIME) ENABLE
   ) ORGANIZATION INDEX NOCOMPRESS PCTFREE 10 INITRANS 2 MAXTRANS 255 LOGGING;

  GRANT UPDATE ON AMO.AM_METRIC_HIST TO AMU;
  GRANT SELECT ON AMO.AM_METRIC_HIST TO AMU;
  GRANT INSERT ON AMO.AM_METRIC_HIST TO AMU;
  GRANT DELETE ON AMO.AM_METRIC_HIST TO AMU;
--------------------------------------------------------
--  DDL for Table AM_METRIC_LOAD
--------------------------------------------------------

  CREATE TABLE AMO.AM_METRIC_LOAD 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	SERVER VARCHAR2(30 CHAR), 
	SPACE_TIME DATE, 
	METRIC VARCHAR2(50 CHAR), 
	VALUE NUMBER
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
         SKIP 2
         FIELDS TERMINATED BY ', '
         MISSING FIELD VALUES ARE NULL
         (database_name, server, SPACE_TIME date 'DD-MM-YY HH24:MI:SS', metric, value)
          )
      LOCATION
       ( AMCHECK_DIR:'am_metric_load.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.AM_METRIC_LOAD TO AMU;
--------------------------------------------------------
--  DDL for Table AM_METRIC_REPORT
--------------------------------------------------------

  CREATE TABLE AMO.AM_METRIC_REPORT 
   (	METRIC CHAR(32 BYTE), 
	SPACE_TIME CHAR(17 BYTE), 
	FILLER1 CHAR(1 BYTE), 
	NOWCOL CHAR(10 BYTE), 
	FIVEMIN CHAR(10 BYTE), 
	TENMIN CHAR(10 BYTE), 
	FIFTEENMIN CHAR(10 BYTE), 
	THIRTYMIN CHAR(10 BYTE), 
	FORTYFIVEMIN CHAR(10 BYTE), 
	SIXTYMIN CHAR(10 BYTE), 
	FILLER2 CHAR(1 BYTE), 
	FIFTEENAV CHAR(10 BYTE), 
	HOURAV CHAR(10 BYTE), 
	TWOHRAV CHAR(10 BYTE), 
	SIXHRAV CHAR(10 BYTE), 
	TODAYAV CHAR(10 BYTE), 
	YDAYAV CHAR(10 BYTE)
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
             SKIP 3 FIELDS (
                metric (1:33),
                space_time (34:50),
                filler1 (52),
                nowcol (54:63),
                fivemin (65:74),
                tenmin (76:85),
                fifteenmin (87:96),
                thirtymin (98:107),
                fortyfivemin (109:118),
                sixtymin (120:129),
                filler2 (131),
                fifteenav (133:142),
                hourav (144:153),
                twohrav (155:164),
                sixhrav (166:175),
                todayav (177:186),
                ydayav (188:197)
              )
      )
      LOCATION
       ( AMCHECK_DIR:'am_metric_check.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.AM_METRIC_REPORT TO AMU;
--------------------------------------------------------
--  DDL for Table AM_ORACLE_LICENSE
--------------------------------------------------------

  CREATE TABLE AMO.AM_ORACLE_LICENSE 
   (	NAME VARCHAR2(50 CHAR), 
	CONTRACT_NO NUMBER, 
	START_DATE DATE, 
	END_DATE DATE, 
	SI_NUMBER NUMBER, 
	SERVICE_PRODUCT VARCHAR2(100 CHAR), 
	PRODUCT_DESCRIPTION VARCHAR2(200 CHAR), 
	LICENSE_PRICING_QUANTITY NUMBER, 
	CONTRACT_AMOUNT NUMBER, 
	CURRENCY VARCHAR2(3 CHAR), 
	LICENSED_TYPE CHAR(1 BYTE) DEFAULT 'C'
   );

   COMMENT ON TABLE AMO.AM_ORACLE_LICENSE  IS 'License details as supplied by Oracle Corp';
  GRANT SELECT ON AMO.AM_ORACLE_LICENSE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_ORACLE_LICENSE_LOAD
--------------------------------------------------------

  CREATE TABLE AMO.AM_ORACLE_LICENSE_LOAD 
   (	NAME VARCHAR2(30 CHAR), 
	CONTRACT_NO VARCHAR2(10 CHAR), 
	START_DATE VARCHAR2(12 CHAR), 
	END_DATE VARCHAR2(12 CHAR), 
	SI_NUMBER VARCHAR2(10 CHAR), 
	SERVICE_PRODUCT VARCHAR2(100 CHAR), 
	PRODUCT_DESCRIPTION VARCHAR2(200 CHAR), 
	LICENSE_PRICING_QUANTITY VARCHAR2(10 CHAR), 
	CONTRACT_AMOUNT VARCHAR2(10 CHAR), 
	CURRENCY VARCHAR2(6 CHAR)
   );

--------------------------------------------------------
--  DDL for Table AM_ORACLE_LICENSE_MAPPING
--------------------------------------------------------

  CREATE TABLE AMO.AM_ORACLE_LICENSE_MAPPING 
   (	CONTRACT_NO NUMBER, 
	PRODUCT_DESCRIPTION VARCHAR2(200 CHAR), 
	LICENSED_NAME VARCHAR2(30 CHAR), 
	LICENSED_TYPE CHAR(1 BYTE) DEFAULT 'C', 
	 CONSTRAINT PK_ORAC_LIC_MAP PRIMARY KEY (CONTRACT_NO, PRODUCT_DESCRIPTION, LICENSED_NAME, LICENSED_TYPE) ENABLE
   ) ORGANIZATION INDEX ;

   COMMENT ON COLUMN AMO.AM_ORACLE_LICENSE_MAPPING.LICENSED_TYPE IS 'C for CPU and U for named user Plus';
  GRANT SELECT ON AMO.AM_ORACLE_LICENSE_MAPPING TO AMU;
--------------------------------------------------------
--  DDL for Table AM_ORACLE_LICENSE_UNITS
--------------------------------------------------------

  CREATE TABLE AMO.AM_ORACLE_LICENSE_UNITS 
   (	LICENSED_NAME VARCHAR2(30 CHAR), 
	LICENSED_TYPE CHAR(1 BYTE) DEFAULT 'C', 
	LICENSED_QUANTITY NUMBER
   );

   COMMENT ON COLUMN AMO.AM_ORACLE_LICENSE_UNITS.LICENSED_NAME IS 'Server name for physical servers else cluster name';
   COMMENT ON COLUMN AMO.AM_ORACLE_LICENSE_UNITS.LICENSED_TYPE IS 'C for CPU U for Named User Plus S for Socket';
   COMMENT ON COLUMN AMO.AM_ORACLE_LICENSE_UNITS.LICENSED_QUANTITY IS 'quantity after applying any multiplier or modifier';
  GRANT SELECT ON AMO.AM_ORACLE_LICENSE_UNITS TO AMU;
--------------------------------------------------------
--  DDL for Table AM_OS_SPACE
--------------------------------------------------------

  CREATE TABLE AMO.AM_OS_SPACE 
   (	SERVER VARCHAR2(30 CHAR), 
	FILESYSTEM VARCHAR2(200 CHAR), 
	SIZEK NUMBER(10,0), 
	USEDK NUMBER(10,0), 
	AVAILK NUMBER(10,0), 
	PCTUSED NUMBER(3,0), 
	MOUNTPOINT VARCHAR2(200 CHAR), 
	SPACE_TIME DATE, 
	 CONSTRAINT PK_AM_OS_SPACE PRIMARY KEY (SERVER, MOUNTPOINT, SPACE_TIME) ENABLE
   ) ORGANIZATION INDEX;

  GRANT DELETE ON AMO.AM_OS_SPACE TO AMU;
  GRANT INSERT ON AMO.AM_OS_SPACE TO AMU;
  GRANT SELECT ON AMO.AM_OS_SPACE TO AMU;
  GRANT UPDATE ON AMO.AM_OS_SPACE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_OS_SPACE_LOAD
--------------------------------------------------------

  CREATE TABLE AMO.AM_OS_SPACE_LOAD 
   (	SERVER VARCHAR2(30 CHAR), 
	FILESYSTEM VARCHAR2(200 CHAR), 
	SIZEK NUMBER(10,0), 
	USEDK NUMBER(10,0), 
	AVAILK NUMBER(10,0), 
	PCTUSED NUMBER(3,0), 
	MOUNTPOINT VARCHAR2(200 CHAR), 
	DF_DOW VARCHAR2(10 CHAR), 
	DF_TIMESTAMP VARCHAR2(40 CHAR)
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
             SKIP 0 FIELDS TERMINATED BY ', ' MISSING FIELD VALUES ARE NULL
          )
      LOCATION
       ( AMCHECK_DIR:'am_os_space_load.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.AM_OS_SPACE_LOAD TO AMU;
--------------------------------------------------------
--  DDL for Table AM_PARAMETER
--------------------------------------------------------

  CREATE TABLE AMO.AM_PARAMETER 
   (	PARAM_TYPE VARCHAR2(10 CHAR), 
	PARAM_NAME VARCHAR2(30 CHAR), 
	PARAM_PARENT VARCHAR2(30 CHAR), 
	PARAM_GRAND_PARENT VARCHAR2(30 CHAR), 
	PARAM_VALUE_CHAR VARCHAR2(2000 CHAR), 
	PARAM_VALUE_NUM NUMBER, 
	PARAM_VALUE_TIME TIMESTAMP (6)
   );

   COMMENT ON COLUMN AMO.AM_PARAMETER.PARAM_PARENT IS 'Non-null if a hierarchy is necessary eg servername used to uniquely identify a database';
   COMMENT ON COLUMN AMO.AM_PARAMETER.PARAM_GRAND_PARENT IS 'Non-null if a hierarchy is necessary eg servername used to uniquely identify a database';
   COMMENT ON TABLE AMO.AM_PARAMETER  IS 'Optional values for fine tuning queries';

  GRANT DELETE ON AMO.AM_PARAMETER TO AMU;
  GRANT INSERT ON AMO.AM_PARAMETER TO AMU;
  GRANT SELECT ON AMO.AM_PARAMETER TO AMU;
  GRANT UPDATE ON AMO.AM_PARAMETER TO AMU;

-- The next contrived example sets a limit of 70% for tablespace checks for all databases on server01
-- except for tablespaces on oemdev which all have a limit of 60%
--..except for tablespace 'users' which has a 50% limit!

INSERT INTO am_parameter (param_type, param_name, param_value_num)
VALUES ('SPACE', 'server01', 70);

INSERT INTO am_parameter (param_type, param_name, param_parent, param_value_num)
VALUES ('SPACE', 'OEMDEV', 'server01', 60);

INSERT INTO am_parameter (param_type, param_name, param_parent, param_grand_parent, param_value_num)
VALUES ('SPACE', 'USERS', 'OEMDEV', 'server01', 50);

GRANT SELECT, INSERT, UPDATE, DELETE ON amo.am_parameter to amu;

--------------------------------------------------------
--  DDL for Table AM_PROG_DATABASE
--------------------------------------------------------

  CREATE TABLE AMO.AM_PROG_DATABASE 
   (	SERVER VARCHAR2(30 CHAR), 
	INSTANCE_NAME VARCHAR2(30 CHAR), 
	PARENT_NAME VARCHAR2(30 CHAR), 
	DB_NAME VARCHAR2(30 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N'
   );
  GRANT SELECT ON AMO.AM_PROG_DATABASE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_PROG_INSTANCE
--------------------------------------------------------

  CREATE TABLE AMO.AM_PROG_INSTANCE 
   (	SERVER VARCHAR2(30 CHAR), 
	INSTANCE_NAME VARCHAR2(30 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N'
   );
  GRANT SELECT ON AMO.AM_PROG_INSTANCE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_PROG_SERVER
--------------------------------------------------------

  CREATE TABLE AMO.AM_PROG_SERVER 
   (	SERVER VARCHAR2(30 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	PHYSICAL_SERVER VARCHAR2(100 CHAR), 
	PRODUCTION_IND CHAR(1 BYTE) DEFAULT 'N', 
	RUN_ORDER NUMBER DEFAULT 50, 
	 CONSTRAINT PK_AMPS PRIMARY KEY (SERVER) ENABLE
   ) ORGANIZATION INDEX;

   COMMENT ON TABLE AMO.AM_PROG_SERVER  IS 'all servers need ssh autologin enabled from the monitoring server';
  GRANT SELECT ON AMO.AM_PROG_SERVER TO AMU;
--------------------------------------------------------
--  DDL for Table AM_RECONCILE_LOAD
--------------------------------------------------------

  CREATE TABLE AMO.AM_RECONCILE_LOAD 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	DBID NUMBER(20,0), 
	HOST_NAME VARCHAR2(64 CHAR)
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
             SKIP 0 FIELDS TERMINATED BY ', ' MISSING FIELD VALUES ARE NULL
      )
      LOCATION
       ( AMCHECK_DIR:'am_os_reconcile_load.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.AM_RECONCILE_LOAD TO AMU;
--------------------------------------------------------
--  DDL for Table AM_SCRIPTADD
--------------------------------------------------------

  CREATE TABLE AMO.AM_SCRIPTADD 
   (	SCRIPT_ID VARCHAR2(30 CHAR), 
	DATABASE_NAME VARCHAR2(30 CHAR), 
	ADDED_FROM DATE, 
	ADDED_TO DATE, 
	DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	RUN_ORDER NUMBER DEFAULT 50, 
	SCRIPT_TYPE VARCHAR2(20 CHAR) DEFAULT 'SUMMARY', 
	FREQUENCY VARCHAR2(30 CHAR) DEFAULT 'D'
   );

   COMMENT ON TABLE AMO.AM_SCRIPTADD  IS 'Details on which special scripts are run for specific databases';
  GRANT SELECT ON AMO.AM_SCRIPTADD TO AMU;
--------------------------------------------------------
--  DDL for Table AM_SCRIPTS
--------------------------------------------------------

  CREATE TABLE AMO.AM_SCRIPTS 
   (	SCRIPT_ID VARCHAR2(30 CHAR), 
	SCRIPT_NAME VARCHAR2(200 CHAR), 
	SCRIPT_TYPE VARCHAR2(20 CHAR) DEFAULT 'SUMMARY', 
	DB_VERSION_FROM NUMBER, 
	DB_VERSION_TO NUMBER, 
	FREQUENCY VARCHAR2(30 CHAR) DEFAULT 'D', 
	DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	RUN_ORDER NUMBER DEFAULT 50, 
	PARAM1 VARCHAR2(200 CHAR), 
	RUN_ON_MASTER CHAR(1 CHAR) DEFAULT 'N', 
	PARAM2 VARCHAR2(200 CHAR), 
	 CONSTRAINT PK_AM_SCRIPTS PRIMARY KEY (SCRIPT_ID) ENABLE
   ) ORGANIZATION INDEX;
 
   COMMENT ON COLUMN AMO.AM_SCRIPTS.SCRIPT_ID IS 'Must be unique but an actual script can have multiple entries';
   COMMENT ON COLUMN AMO.AM_SCRIPTS.FREQUENCY IS 'D - Daily W - Weekly';
   COMMENT ON TABLE AMO.AM_SCRIPTS  IS 'Details on valid AMCheck scripts';

INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('AMA','amazon_disclaimer.sql','SPECIAL',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('ANAL','when_analyzed.sql','SUMMARY',null,null,'D','N',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('ARCHIVELOG','archivelog_check.sql','CHECK',null,null,'D','N',55,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('BROKEN','broken_jobs.sql','CHECK',null,null,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('CATALOGS','rman_catalog_summary.sql','SPECIAL',null,null,'D','N',160,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('CHKHEADER','standard_checks_header.sql','CHECK',null,null,'D','N',140,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('CLUSTERSUM','cluster_summary','SPECIAL',null,null,'D','N',160,null,'Y',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('DFSPACE','dfspace_check.sql','CHECK',null,null,'D','Y',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('EXPIRE','am_expire.sql','CHECK',null,null,'D','N',40,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('FEATURES','dba_feature_usage.sql','SUMMARY',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('GROWTH','growth_report.sql','SUMMARY',null,null,'D','N',50,'DBNAME','Y',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('INST10','102_instance_summary.sql','ALL',102,null,'D','N',10,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('INSTANCE','instance_summary.sql','ALL',null,101,'D','N',10,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('OSSCHK','os_space_check.sql','CHECK',null,null,'D','N',50,'DBNAME','Y',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('OSSSUM','os_space_summary.sql','SUMMARY',null,null,'D','N',50,'DBNAME','Y',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('PASSWORD','password_expiry_check.sql','CHECK',null,102,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('PASSWORD11','password_expiry_check11.sql','CHECK',110,null,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('PROMPT','prompt.sql','SUMMARY',null,null,'D','N',51,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('RECENTOBJ','recent_creations.sql','SUMMARY',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('REDO','redo_check.sql','CHECK',null,null,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('REDOACT','redo_activity.sql','SUMMARY',null,null,'D','N',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('RMANC10','rman_check_10.sql','CHECK',102,null,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('RMANCR12','rman_check_r12.sql','CHECK',102,null,'D','Y',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('RMANDIS','rman_disclaimer.sql','SPECIAL',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('RMANS10','rman_summary_10.sql','SUMMARY',102,null,'D','N',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('RMANSPEED','rman_speed.sql','SPECIAL',null,null,'D','N',155,'DBNAME','N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('RMANSPEEDDB','rman_speed_db.sql','CHECK',102,null,'D','N',55,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('SEGGROWTH','segment_growth.sql','SUMMARY',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('SPACE','space_summary.sql','SUMMARY',null,null,'D','N',48,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('SPACECHK','space_check.sql','CHECK',null,null,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('SPACEG','true_space_gig.sql','SUMMARY',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('SPACEM','true_space_meg.sql','SUMMARY',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('SPACER','prompt.sql','SUMMARY',null,null,'D','N',49,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('SPACET','true_space_check.sql','CHECK',null,null,'D','Y',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('STATS','stats_check.sql','CHECK',null,null,'D','Y',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('STATS10','stats_check_10.sql','CHECK',102,null,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('STATS9','stats_check_9.sql','CHECK',null,101,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('STDBY','standby_check.sql','CHECK',null,null,'D','N',150,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('TABLESPACE','tablespace_growth_report.sql','SUMMARY',null,null,'D','N',50,'SID','Y','SERVER');
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('TOTRACE','totrace.sql','SUMMARY',112,null,'D','N',55,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('TOTSPACE','total_space.sql','SUMMARY',null,null,'D','Y',50,null,'N',null);
INSERT INTO amo.am_scripts (SCRIPT_ID,SCRIPT_NAME,SCRIPT_TYPE,DB_VERSION_FROM,DB_VERSION_TO,FREQUENCY,DISABLED,RUN_ORDER,PARAM1,RUN_ON_MASTER,PARAM2) values ('TSGROWTH','tablespace_growth_check','SUMMARY',null,null,'D','N',160,'DBNAME','Y','N');

commit;

  GRANT SELECT ON AMO.AM_SCRIPTS TO AMU;
--------------------------------------------------------
--  DDL for Table AM_SCRIPTSKIP
--------------------------------------------------------

  CREATE TABLE AMO.AM_SCRIPTSKIP 
   (	SCRIPT_ID VARCHAR2(30 CHAR), 
	DATABASE_NAME VARCHAR2(30 CHAR), 
	SKIPPED_FROM DATE, 
	SKIPPED_TO DATE, 
	DISABLED CHAR(1 CHAR) DEFAULT 'N'
   );

   COMMENT ON TABLE AMO.AM_SCRIPTSKIP  IS 'Details on which skips are omitted for specific databases';
  GRANT SELECT ON AMO.AM_SCRIPTSKIP TO AMU;
--------------------------------------------------------
--  DDL for Table AM_SCRIPT_SET
--------------------------------------------------------

  CREATE TABLE AMO.AM_SCRIPT_SET 
   (	SET_ID VARCHAR2(30 CHAR), 
	SCRIPT_ID VARCHAR2(30 CHAR), 
	DATABASE_NAME VARCHAR2(30 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	RUN_ORDER NUMBER(2,0) DEFAULT 1, 
	TITLE VARCHAR2(30 CHAR)
   );

CREATE INDEX AMO.AM_SCRSET ON AMO.AM_SCRIPT_SET (SET_ID, SCRIPT_ID);

   COMMENT ON TABLE AMO.AM_SCRIPT_SET  IS 'Group scripts (normally for a specific database) together for 1 report';
  GRANT UPDATE ON AMO.AM_SCRIPT_SET TO AMU;
  GRANT SELECT ON AMO.AM_SCRIPT_SET TO AMU;
  GRANT INSERT ON AMO.AM_SCRIPT_SET TO AMU;
  GRANT DELETE ON AMO.AM_SCRIPT_SET TO AMU;
--------------------------------------------------------
--  DDL for Table AM_SERVER
--------------------------------------------------------

  CREATE TABLE AMO.AM_SERVER 
   (	SERVER VARCHAR2(30 CHAR), 
	AUTOSTART_ENABLED CHAR(1 CHAR) DEFAULT 'N', 
	DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	CLUSTER_NAME VARCHAR2(50 CHAR), 
	PHYSICAL_SERVER VARCHAR2(100 CHAR), 
	PING_DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	PHYSICAL_SERVER_ABBREV VARCHAR2(100 CHAR) GENERATED ALWAYS AS (SUBSTR(PHYSICAL_SERVER,1,INSTR(PHYSICAL_SERVER,'.',1,1)-1)) VIRTUAL VISIBLE 
   );

   COMMENT ON COLUMN AMO.AM_SERVER.PHYSICAL_SERVER IS 'fully qualified server name';
  GRANT SELECT ON AMO.AM_SERVER TO AMR;
  GRANT SELECT ON AMO.AM_SERVER TO AMU;
--------------------------------------------------------
--  DDL for Table AM_SIDSKIP
--------------------------------------------------------
/************************************************************************************************************/
/* This table should probably use intervals for the time components but I found coding difficult            */
/* and data loading difficult with intervals. So I've gone for less efficient but more                      */
/* manageable datatypes. If someone wants to rewrite ..please do!                                           */
/*                                                                                                          */
/* This table takes three types of entries:                                                                 */
/*     a) Type 'DAILY' - the outage applies every day ..subject to other columns                            */
/*     b) Type of certain day of the week only e.g. 'MONDAY' - outage only applies for that day (each week) */
/*     c) Type of date within each month e.g. '31' - outage only applies for that day (each month)          */
/* A combination of the above should cater for all conditions. You may need multiple entries to fully       */
/* desribe an outage window e.g. a window that spans multiple consecutive days. Here are some examples:     */
/*                                                                                                          */
/* DATABASE_NAME            SIDSKIP_TY DATE_FROM DATE_TO    HOUR_FROM MINUTE_FROM    HOUR_TO  MINUTE_TO     */
/* ------------------------ ---------- --------- --------- ---------- ----------- ---------- ----------     */
/* OEMDB01.WORLD            DAILY      10-AUG-15 10-AUG-16         23          00                           */
/* OEMDB01.WORLD            TUESDAY    10-AUG-15                                                            */
/* PRDDB.WORLD              SUNDAY                                 17          59                           */
/* PRDDD.WORLD              MONDAY                                                         5          0     */
/* DEV01.WORLD              1                                      19          14                           */
/* DEV01.WORLD              2                                                              6          0     */
/*                                                                                                          */
/* OEMDB01 has an outage between 11pm and midnight every day for a year starting on 10th August 2015.       */
/* It also has an outage all day every Tuesday.                                                             */
/* PRDDB has an outage every week from Sunday at 5:59 pm until 5:00 am the following day (Monday).          */
/* DEV01 has an outage every month from 7:14pm on 1st of the Month until 6:00 am on 2nd.                    */
/* If you don't specify a 'from time' it will be treated as midnight.                                       */
/* If you don't specify a 'to time' it will be treated as 23:59.  All times assume a 24hour clock.          */
/************************************************************************************************************/

  CREATE TABLE AMO.AM_SIDSKIP 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	SIDSKIP_TYPE VARCHAR2(10 CHAR) DEFAULT 'DAILY', 
	DATE_FROM DATE, 
	DATE_TO DATE, 
	HOUR_FROM NUMBER(2,0), 
	MINUTE_FROM NUMBER(2,0), 
	HOUR_TO NUMBER(2,0), 
	MINUTE_TO NUMBER(2,0), 
	SIDSKIP_NOTES VARCHAR2(200 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N'
   );

   COMMENT ON TABLE AMO.AM_SIDSKIP  IS 'List of blackouts for alerting by database';
  GRANT DELETE ON AMO.AM_SIDSKIP TO AMU;
  GRANT INSERT ON AMO.AM_SIDSKIP TO AMU;
  GRANT SELECT ON AMO.AM_SIDSKIP TO AMU;
  GRANT UPDATE ON AMO.AM_SIDSKIP TO AMU;
--------------------------------------------------------
--  DDL for Table AM_SPACE_THRESHOLD
--------------------------------------------------------

  CREATE TABLE AMO.AM_SPACE_THRESHOLD 
   (	SERVER VARCHAR2(30 CHAR), 
	FILESYSTEM VARCHAR2(200 CHAR), 
	ERROR_PCT_DAY NUMBER(3,0), 
	ERROR_PCT_WEEK NUMBER(3,0), 
	ERROR_PCT_MONTH NUMBER(3,0), 
	ERROR_SIZE_IN_K NUMBER
   );

  GRANT SELECT ON AMO.AM_SPACE_THRESHOLD TO AMU;
--------------------------------------------------------
--  DDL for Table AM_TABLESPACE_MONTH_SPACE
--------------------------------------------------------

  CREATE TABLE AMO.AM_TABLESPACE_MONTH_SPACE 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	SERVER VARCHAR2(30 CHAR), 
	TABLESPACE_NAME VARCHAR2(30 CHAR), 
	SPACE_TIME DATE, 
	MEG_DATA NUMBER(9,2), 
	MEG_FREE NUMBER(9,2), 
	MEG_USED NUMBER(9,2), 
	MEG_TEMP NUMBER(9,2)
   );

  GRANT SELECT ON AMO.AM_TABLESPACE_MONTH_SPACE TO AMU;
  GRANT UPDATE ON AMO.AM_TABLESPACE_MONTH_SPACE TO AMU;
  GRANT INSERT ON AMO.AM_TABLESPACE_MONTH_SPACE TO AMU;
  GRANT DELETE ON AMO.AM_TABLESPACE_MONTH_SPACE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_TABLESPACE_SPACE
--------------------------------------------------------

  CREATE TABLE AMO.AM_TABLESPACE_SPACE 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	SERVER VARCHAR2(30 CHAR), 
	TABLESPACE_NAME VARCHAR2(30 CHAR), 
	SPACE_TIME DATE, 
	MEG_DATA NUMBER(9,2), 
	MEG_FREE NUMBER(9,2), 
	MEG_USED NUMBER(9,2), 
	MEG_TEMP NUMBER(9,2), 
	 CONSTRAINT PK_AM_TABLESPACE_SPACE PRIMARY KEY (DATABASE_NAME, SERVER, TABLESPACE_NAME, SPACE_TIME) ENABLE
   ) ORGANIZATION INDEX ;

  GRANT INSERT ON AMO.AM_TABLESPACE_SPACE TO AMU;
  GRANT SELECT ON AMO.AM_TABLESPACE_SPACE TO AMU;
  GRANT UPDATE ON AMO.AM_TABLESPACE_SPACE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_TABLESPACE_SPACE_LOAD
--------------------------------------------------------

  CREATE TABLE AMO.AM_TABLESPACE_SPACE_LOAD 
   (	SERVER VARCHAR2(30 CHAR), 
	DATABASE_NAME VARCHAR2(30 CHAR), 
	TABLESPACE_NAME VARCHAR2(30 CHAR), 
	SPACE_TIME DATE, 
	MEG_DATA NUMBER(9,2), 
	MEG_FREE NUMBER(9,2), 
	MEG_USED NUMBER(9,2), 
	MEG_TEMP NUMBER(9,2)
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
         SKIP 2 FIELDS TERMINATED BY ', ' MISSING FIELD VALUES ARE NULL             )
      LOCATION
       ( AMCHECK_DIR:'am_tablespace_space_load.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.AM_TABLESPACE_SPACE_LOAD TO AMU;
--------------------------------------------------------
--  DDL for Table AM_TOTAL_SPACE
--------------------------------------------------------

  CREATE TABLE AMO.AM_TOTAL_SPACE 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	SERVER VARCHAR2(30 CHAR), 
	SPACE_TIME DATE, 
	GIG_DATA NUMBER(9,2), 
	GIG_FREE NUMBER(9,2), 
	GIG_USED NUMBER(9,2), 
	GIG_TEMP NUMBER(9,2), 
	 CONSTRAINT PK_AM_TOTAL_SPACE PRIMARY KEY (DATABASE_NAME, SERVER, SPACE_TIME) ENABLE
   ) ORGANIZATION INDEX;

  GRANT INSERT ON AMO.AM_TOTAL_SPACE TO AMU;
  GRANT SELECT ON AMO.AM_TOTAL_SPACE TO AMU;
  GRANT UPDATE ON AMO.AM_TOTAL_SPACE TO AMU;
--------------------------------------------------------
--  DDL for Table AM_TOTAL_SPACE_LOAD
--------------------------------------------------------

  CREATE TABLE AMO.AM_TOTAL_SPACE_LOAD 
   (	DATABASE_NAME VARCHAR2(30 CHAR), 
	SERVER VARCHAR2(30 CHAR), 
	SPACE_TIME DATE, 
	GIG_DATA NUMBER(9,2), 
	GIG_FREE NUMBER(9,2), 
	GIG_USED NUMBER(9,2), 
	GIG_TEMP NUMBER(9,2)
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
         SKIP 2 FIELDS TERMINATED BY ', ' MISSING FIELD VALUES ARE NULL             )
      LOCATION
       ( AMCHECK_DIR:'am_total_space_load.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.AM_TOTAL_SPACE_LOAD TO AMU;

--------------------------------------------------------
--  DDL for Table DFSPACE
--------------------------------------------------------

  CREATE TABLE AMO.DFSPACE 
   (	FULL_FILE_NAME VARCHAR2(513 CHAR), 
	FILE_NAME VARCHAR2(30 CHAR), 
	DIR_NAME VARCHAR2(50 CHAR), 
	FILE_SYSTEM VARCHAR2(50 CHAR), 
	FREE_SPACE NUMBER, 
	MOUNT_POINT VARCHAR2(50 CHAR), 
	SPACE_CHARTIME VARCHAR2(17 CHAR)
   ) 
   ORGANIZATION EXTERNAL 
    ( TYPE ORACLE_LOADER
      DEFAULT DIRECTORY AMCHECK_DIR
      ACCESS PARAMETERS
      ( RECORDS DELIMITED BY NEWLINE NOBADFILE NODISCARDFILE NOLOGFILE
         FIELDS TERMINATED BY ' ' MISSING FIELD VALUES ARE NULL             )
      LOCATION
       ( AMCHECK_DIR:'dfspace.dbf'
       )
    )
   REJECT LIMIT UNLIMITED ;
  GRANT SELECT ON AMO.DFSPACE TO AMU;

--------------------------------------------------------
--  DDL for Table SS_INSTANCE
--------------------------------------------------------

  CREATE TABLE AMO.SS_INSTANCE 
   (	SERVER VARCHAR2(30 CHAR), 
	INSTANCE_NAME VARCHAR2(30 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N'
   );

  GRANT INSERT ON AMO.SS_INSTANCE TO AMU;
  GRANT SELECT ON AMO.SS_INSTANCE TO AMU;
  GRANT UPDATE ON AMO.SS_INSTANCE TO AMU;
--------------------------------------------------------
--  DDL for Table SS_SERVER
--------------------------------------------------------

  CREATE TABLE AMO.SS_SERVER 
   (	SERVER VARCHAR2(30 CHAR), 
	DISABLED CHAR(1 CHAR) DEFAULT 'N', 
	 CONSTRAINT PK_SS_SERVER PRIMARY KEY (SERVER) ENABLE
   ) ORGANIZATION INDEX;

  GRANT INSERT ON AMO.SS_SERVER TO AMU;
  GRANT SELECT ON AMO.SS_SERVER TO AMU;
  GRANT UPDATE ON AMO.SS_SERVER TO AMU;

--------------------------------------------------------
--  DDL for View NEW_RMAN_DETAILS
--------------------------------------------------------

  CREATE OR REPLACE FORCE VIEW AMO.NEW_RMAN_DETAILS (DBID, DB_NAME, INPUT_TYPE, STATUS, LAST_TIME) AS 
  SELECT x.dbid,
       j.db_name,
       j.input_type,
       DECODE(j.status,'FAILED','FAILED    <---- N.B.',j.status) AS status,
       TO_CHAR(MAX(j.start_time),'Day DD Month YYYY HH12:MI:SS (am)') AS last_time
FROM   rman.RC_RMAN_BACKUP_JOB_DETAILS@rman1 j,
       rman.rc_database@rman1 x
WHERE  j.start_time > sysdate -7
AND    j.input_type <> 'DB INCR'
AND    j.db_key = x.db_key
AND    j.db_name = x.name
group by x.dbid, j.db_name, j.status, j.input_type
UNION
SELECT /*+ RULE */
       x.dbid,
       d.db_name,
       DECODE(d.incremental_level,0,'DB FULL','DB INCR'),
       DECODE(j.status,'FAILED','FAILED    <---- N.B.',j.status),
       TO_CHAR(MAX(j.start_time),'Day DD Month YYYY HH12:MI:SS (am)')
FROM   rman.RC_RMAN_BACKUP_JOB_DETAILS@rman1 j,
       rman.RC_BACKUP_SET_DETAILS@rman1 d,
       rman.rc_database@rman1 x
WHERE  j.start_time > sysdate -7
AND    j.input_type = 'DB INCR'
AND    j.db_key = x.db_key
AND    j.db_name = x.name
AND   j.session_key = d.session_key
AND   j.session_recid = d.session_recid
AND   j.session_stamp = d.session_stamp
AND   j.db_key = d.db_key
group by x.dbid, d.db_name, j.status, j.input_type, d.incremental_level;
--------------------------------------------------------
--  DDL for View RMAN_BACKUP_DIRECTORIES
--------------------------------------------------------

  CREATE OR REPLACE FORCE VIEW AMO.RMAN_BACKUP_DIRECTORIES (NAME, DIRECTORY) AS 
  SELECT d.name,
       SUBSTR(p.handle, 1, INSTR(p.handle, '/',-1)-1) AS directory
FROM   rc_backup_piece@rman1 p,
       rc_database@rman1 d
WHERE  p.db_key = d.db_key
AND    p.device_type = 'DISK'
GROUP BY d.name, SUBSTR(p.handle, 1, INSTR(p.handle, '/',-1)-1);
  GRANT SELECT ON AMO.RMAN_BACKUP_DIRECTORIES TO AMU;
--------------------------------------------------------
--  DDL for View RMAN_BACKUP_DIRECTORY
--------------------------------------------------------

  CREATE OR REPLACE FORCE VIEW AMO.RMAN_BACKUP_DIRECTORY (NAME, DBID, DIRECTORY) AS 
  SELECT DISTINCT name, dbid, directory
FROM  (SELECT rbr.db_name AS name,
              rd.dbid  AS dbid,
              SUBSTR(handle, 1, INSTR(handle, '/',-1)-1) AS directory
       FROM   rman.rc_backup_redolog@rman1 rbr,
              rman.rc_backup_piece@rman1 rbp,
              rman.rc_database@rman1 rd
       where  rbr.db_key=rbp.db_key
       and    rbr.bs_key=rbp.bs_key
       AND    rbr.db_key=rd.db_key
       and    rbr.status= 'A'
       and    rbp.media IS NULL
       UNION ALL
       SELECT rbd.db_name,
              rb.dbid,
              SUBSTR(handle, 1, INSTR(handle, '/',-1)-1)
       FROM   rman.rc_backup_datafile@rman1 rbd,
              rman.rc_datafile@rman1 rd,
              rman.rc_backup_piece@rman1 rbp,
              rman.rc_database@rman1 rb
       WHERE  rbd.db_key=rd.db_key
       AND    rbd.db_key=rbp.db_key
       AND    rbd.file#=rd.file#
       AND    rbd.bs_key=rbp.bs_key
       AND    rbd.db_key=rb.db_key
       AND    rbd.status = 'A'
       AND    rbp.media IS NULL
       AND    rd.drop_time IS NULL
       UNION ALL
       SELECT rbc.db_name,
              rb.dbid,
              SUBSTR(handle, 1, INSTR(handle, '/',-1)-1) AS directory
       FROM   rman.rc_backup_controlfile@rman1 rbc,
              rman.rc_backup_piece@rman1 rbp,
              rman.rc_database@rman1 rb
       WHERE  rbc.db_key=rbp.db_key
       AND    rbc.bs_key=rbp.bs_key
       AND    rbc.db_key=rb.db_key
       AND    rbc.status = 'A'
       AND    rbp.media IS NULL
       UNION ALL
       SELECT rd.name,
              rd.dbid,
              SUBSTR(handle, 1, INSTR(handle, '/',-1)-1)
       FROM   rman.rc_backup_spfile@rman1 rbs,
              rman.rc_backup_piece@rman1 rbp,
              rman.rc_database@rman1 rd
       WHERE  rbs.db_key=rd.db_key
       AND    rbs.db_key=rbp.db_key
       AND    rbs.bs_key=rbp.bs_key
       AND    rbs.status = 'A'
       AND    rbp.media IS NULL);
  GRANT SELECT ON AMO.RMAN_BACKUP_DIRECTORY TO AMR;
  GRANT SELECT ON AMO.RMAN_BACKUP_DIRECTORY TO AMU;
--------------------------------------------------------
--  DDL for View RMAN_DETAILS
--------------------------------------------------------

  CREATE OR REPLACE FORCE VIEW AMO.RMAN_DETAILS (DBID, DB_NAME, INPUT_TYPE, STATUS, LAST_TIME) AS 
  SELECT x.dbid,
       j.db_name,
       DECODE(j.input_type,'DB FULL','DATABASE',input_type),
       DECODE(j.status,'FAILED','FAILED    <---- N.B.',j.status) AS status,
       TO_CHAR(MAX(j.start_time),'Day DD Month YYYY HH12:MI:SS (am)') AS last_time
FROM   rman.RC_RMAN_BACKUP_JOB_DETAILS@rman1 j,
       rman.rc_database@rman1 x
WHERE  j.start_time > sysdate -8
AND    j.input_type NOT LIKE 'DB INCR'
AND    j.db_key = x.db_key
AND    j.db_name = x.name
group by x.dbid, j.db_name, j.status, j.input_type
UNION
SELECT /*+ RULE */
       x.dbid,
       x.name as dbname,
       DECODE(j.input_type,'DB INCR','DATABASE',input_type),
       DECODE(j.status,'FAILED','FAILED    <---- N.B.',j.status),
       TO_CHAR(MAX(j.start_time),'Day DD Month YYYY HH12:MI:SS (am)') as start_time
FROM   rman.RC_RMAN_BACKUP_JOB_DETAILS@rman1 j,
       rman.RC_BACKUP_SET_DETAILS@rman1 d,
       rman.rc_database@rman1 x
WHERE  j.start_time > sysdate -8
AND    j.input_type = 'DB INCR'
AND    j.db_key (+) = x.db_key
AND    j.db_name (+) = x.name
AND   j.session_key = d.session_key    (+)
AND   j.session_recid = d.session_recid    (+)
AND   j.session_stamp = d.session_stamp    (+)
AND   j.db_key = d.db_key    (+)
group by x.dbid, x.name, j.status, j.input_type;
  GRANT SELECT ON AMO.RMAN_DETAILS TO AMR;
  GRANT SELECT ON AMO.RMAN_DETAILS TO AMU;
--------------------------------------------------------
--  DDL for View RMAN_LAST_BACKUP
--------------------------------------------------------

  CREATE OR REPLACE FORCE VIEW AMO.RMAN_LAST_BACKUP (DB, STATUS, LAST_TIME, DBID, START_TIME) AS 
  WITH r AS (
SELECT /*+ RULE */
        x.dbid,
        d.db_name,
        DECODE(d.incremental_level,0,'DB FULL','DB INCR') AS input_type,
        DECODE(j.status,'FAILED','FAILED    <---- N.B.',j.status) AS status,
        TO_CHAR(MAX(j.start_time),'Day DD Month YYYY HH12:MI:SS (am)') AS last_time,
        j.start_time
FROM    rman.RC_RMAN_BACKUP_JOB_DETAILS@rman1 j,
        rman.RC_BACKUP_SET_DETAILS@rman1 d,
        rman.rc_database@rman1 x
WHERE   j.start_time > sysdate -365
AND     j.input_type <> 'ARCHIVELOG'
AND     j.db_key = x.db_key
AND     j.db_name = x.name
AND     j.session_key = d.session_key
AND     j.session_recid = d.session_recid
AND     j.session_stamp = d.session_stamp
AND     j.db_key = d.db_key
GROUP BY x.dbid,
         d.db_name,
    j.start_time,
         j.status,
         j.input_type,
         d.incremental_level)
SELECT DISTINCT z.database_name ||
        CASE WHEN y.db_name = z.database_name THEN NULL ELSE ' (' || y.db_name ||  ')' END AS db,
        y.status,
        y.last_time,
        y.dbid,
        y.ranking
FROM (SELECT RANK() OVER (PARTITION BY dbid order by start_time DESC) AS ranking,
              db_name,
              dbid,
              input_type,
              last_time,
              status
       FROM r) y,
       amo.am_database z
WHERE y.ranking = 1
AND   z.dbid = y.dbid
ORDER BY 1;
  GRANT SELECT ON AMO.RMAN_LAST_BACKUP TO AMR;
  GRANT SELECT ON AMO.RMAN_LAST_BACKUP TO AMU;
--------------------------------------------------------
--  DDL for View RMAN_MISSING_BACKUPS
--------------------------------------------------------

  CREATE OR REPLACE FORCE VIEW AMO.RMAN_MISSING_BACKUPS (DB_NAME, DBID) AS 
  SELECT s.db_name, dbid
FROM (SELECT /*+ RULE */ DISTINCT db_name, db_key FROM rman.RC_BACKUP_SET_DETAILS@rman1
      WHERE BACKUP_TYPE IN ('D','I')
      MINUS
      SELECT /*+ RULE */ DISTINCT db_name, db_key FROM rman.RC_RMAN_BACKUP_JOB_DETAILS@rman1
      WHERE  start_time > sysdate -7
      AND    input_type LIKE 'DB%'
      AND    status = 'COMPLETED') s,
      rman.rc_database@rman1 d
WHERE s.db_key = d.db_key;
  GRANT SELECT ON AMO.RMAN_MISSING_BACKUPS TO AMR;
  GRANT SELECT ON AMO.RMAN_MISSING_BACKUPS TO AMU;

--------------------------------------------------------
--  DDL for Index PK_AM_SCRIPTADD
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_SCRIPTADD ON AMO.AM_SCRIPTADD (SCRIPT_ID, DATABASE_NAME, ADDED_FROM) ;
--------------------------------------------------------
--  DDL for Index PK_ORAC_LIC_MAP
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_ORAC_LIC_MAP ON AMO.AM_ORACLE_LICENSE_MAPPING (CONTRACT_NO, PRODUCT_DESCRIPTION, LICENSED_NAME, LICENSED_TYPE) ;
--------------------------------------------------------
--  DDL for Index PK_DATA
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_DATA ON AMO.AM_DATABASE (DATABASE_NAME) ;
--------------------------------------------------------
--  DDL for Index PK_AM_TOTAL_SPACE
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_TOTAL_SPACE ON AMO.AM_TOTAL_SPACE (DATABASE_NAME, SERVER, SPACE_TIME) ;
--------------------------------------------------------
--  DDL for Index PK_AM_OS_SPACE
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_OS_SPACE ON AMO.AM_OS_SPACE (SERVER, MOUNTPOINT, SPACE_TIME) ;
--------------------------------------------------------
--  DDL for Index IX_SRV_PHYSSRV1
--------------------------------------------------------

  CREATE INDEX AMO.IX_SRV_PHYSSRV1 ON AMO.AM_SERVER (PHYSICAL_SERVER) ;

--------------------------------------------------------
--  DDL for Index UQ_AM_PARAMETER
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.UQ_AM_PARAMETER ON AMO.AM_PARAMETER (PARAM_TYPE, PARAM_NAME, PARAM_PARENT, PARAM_GRAND_PARENT) ;
--------------------------------------------------------
--  DDL for Index PK_SS_SERVER
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_SS_SERVER ON AMO.SS_SERVER (SERVER) ;

--------------------------------------------------------
--  DDL for Index PK_AM_SCRIPTSKIP
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_SCRIPTSKIP ON AMO.AM_SCRIPTSKIP (SCRIPT_ID, DATABASE_NAME, SKIPPED_FROM) ;
--------------------------------------------------------
--  DDL for Index IX_SIDSKIP
--------------------------------------------------------

  CREATE INDEX AMO.IX_SIDSKIP ON AMO.AM_SIDSKIP (DATABASE_NAME, SIDSKIP_TYPE) ;
--------------------------------------------------------
--  DDL for Index PK_AM_SERVER1
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_SERVER1 ON AMO.AM_SERVER (SERVER) ;
--------------------------------------------------------
--  DDL for Index PK_AM_SCRIPT_SET
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_SCRIPT_SET ON AMO.AM_SCRIPT_SET (SET_ID, SCRIPT_ID, DATABASE_NAME) ;
--------------------------------------------------------
--  DDL for Index AM_MONTH_SPACE_DB
--------------------------------------------------------

  CREATE INDEX AMO.AM_MONTH_SPACE_DB ON AMO.AM_TABLESPACE_MONTH_SPACE (DATABASE_NAME, SERVER, TABLESPACE_NAME) ;
--------------------------------------------------------
--  DDL for Index PK_LICENSED_CORES
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_LICENSED_CORES ON AMO.AM_ORACLE_LICENSE_UNITS (LICENSED_NAME, LICENSED_TYPE) ;
--------------------------------------------------------
--  DDL for Index PK_AM_ALERT
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_ALERT ON AMO.AM_ALERT (DATABASE_NAME, ALERT_CREATED) ;
--------------------------------------------------------
--  DDL for Index PK_AMPS
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AMPS ON AMO.AM_PROG_SERVER (SERVER) ;
--------------------------------------------------------
--  DDL for Index UQ_SS_INSTANCE
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.UQ_SS_INSTANCE ON AMO.SS_INSTANCE (SERVER, INSTANCE_NAME) ;

--------------------------------------------------------
--  DDL for Index PK_AM_METRIC_HIST
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_METRIC_HIST ON AMO.AM_METRIC_HIST (DATABASE_NAME, SERVER, METRIC, SPACE_TIME) ;
--------------------------------------------------------
--  DDL for Index PK_AM_ALERT_HISTORY
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_ALERT_HISTORY ON AMO.AM_ALERT_HISTORY (DATABASE_NAME, ALERT_CREATED) ;
--------------------------------------------------------
--  DDL for Index IX_BACK_DB
--------------------------------------------------------

  CREATE INDEX AMO.IX_BACK_DB ON AMO.AM_BACKUP_CONTROL (DATABASE_NAME, FUZZY_CHAR_BEFORE, FUZZY_CHAR_AFTER) ;
--------------------------------------------------------
--  DDL for Index PK_PRIN
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_PRIN ON AMO.AM_PROG_INSTANCE (SERVER, INSTANCE_NAME) ;
--------------------------------------------------------
--  DDL for Index PK_SPTH
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_SPTH ON AMO.AM_SPACE_THRESHOLD (SERVER, FILESYSTEM) ;
--------------------------------------------------------
--  DDL for Index PK_AM_TABLESPACE_SPACE
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_TABLESPACE_SPACE ON AMO.AM_TABLESPACE_SPACE (DATABASE_NAME, SERVER, TABLESPACE_NAME, SPACE_TIME) ;

--------------------------------------------------------
--  DDL for Index PK_AM_SCRIPTS
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_AM_SCRIPTS ON AMO.AM_SCRIPTS (SCRIPT_ID) ;
--------------------------------------------------------
--  DDL for Index PK_PRDA
--------------------------------------------------------

  CREATE UNIQUE INDEX AMO.PK_PRDA ON AMO.AM_PROG_DATABASE (SERVER, INSTANCE_NAME, PARENT_NAME, DB_NAME) ;
--------------------------------------------------------
--  Constraints for Table AM_PARAMETER
--------------------------------------------------------

  ALTER TABLE AMO.AM_PARAMETER MODIFY (PARAM_NAME NOT NULL ENABLE);
  ALTER TABLE AMO.AM_PARAMETER MODIFY (PARAM_TYPE NOT NULL ENABLE);
--------------------------------------------------------
--  Constraints for Table SS_INSTANCE
--------------------------------------------------------

  ALTER TABLE AMO.SS_INSTANCE ADD CONSTRAINT CK_SSIN_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.SS_INSTANCE MODIFY (SERVER NOT NULL ENABLE);
--------------------------------------------------------
--  Constraints for Table AM_SCRIPT_SET
--------------------------------------------------------

  ALTER TABLE AMO.AM_SCRIPT_SET ADD CONSTRAINT PK_AM_SCRIPT_SET PRIMARY KEY (SET_ID, SCRIPT_ID, DATABASE_NAME)
  USING INDEX;

  ALTER TABLE AMO.AM_SCRIPT_SET MODIFY (DATABASE_NAME NOT NULL ENABLE);
  ALTER TABLE AMO.AM_SCRIPT_SET MODIFY (SCRIPT_ID NOT NULL ENABLE);
--------------------------------------------------------
--  Constraints for Table AM_SCRIPTS
--------------------------------------------------------

  ALTER TABLE AMO.AM_SCRIPTS ADD CONSTRAINT CK_SCRIPT_ROM CHECK (run_on_master IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_SCRIPTS ADD CONSTRAINT CK_SCRIPT_NAM CHECK (script_name NOT LIKE '%/%') ENABLE;
  ALTER TABLE AMO.AM_SCRIPTS ADD CONSTRAINT CK_SCRIPT_TYP CHECK (script_type IN ('CHECK', 'SUMMARY', 'SPECIAL', 'ALL')) ENABLE;
  ALTER TABLE AMO.AM_SCRIPTS ADD CONSTRAINT CK_SCRIPT_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_SCRIPTS ADD CONSTRAINT PK_AM_SCRIPTS PRIMARY KEY (SCRIPT_ID)
  USING INDEX ;
--------------------------------------------------------
--  Constraints for Table AM_SERVER
--------------------------------------------------------

  ALTER TABLE AMO.AM_SERVER ADD CONSTRAINT PK_AM_SERVER PRIMARY KEY (SERVER)
  USING INDEX;
  ALTER TABLE AMO.AM_SERVER ADD CONSTRAINT CK_SERVER_PINGDIS CHECK (ping_disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_SERVER ADD CONSTRAINT CK_SERVER_AUTO CHECK (autostart_enabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_SERVER ADD CONSTRAINT CK_SERVER_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;

--------------------------------------------------------
--  Constraints for Table AM_SCRIPTSKIP
--------------------------------------------------------

  ALTER TABLE AMO.AM_SCRIPTSKIP ADD CONSTRAINT CK_SCRSKP_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
--------------------------------------------------------
--  Constraints for Table AM_ORACLE_LICENSE_UNITS
--------------------------------------------------------

  ALTER TABLE AMO.AM_ORACLE_LICENSE_UNITS ADD CONSTRAINT CK_LIC_TYPE CHECK (licensed_type IN ('C', 'U', 'S')) ENABLE;
  ALTER TABLE AMO.AM_ORACLE_LICENSE_UNITS ADD CONSTRAINT PK_LICENSED_CORES PRIMARY KEY (LICENSED_NAME, LICENSED_TYPE)
  USING INDEX;

--------------------------------------------------------
--  Constraints for Table AM_PROG_INSTANCE
--------------------------------------------------------

  ALTER TABLE AMO.AM_PROG_INSTANCE ADD CONSTRAINT PK_PRIN PRIMARY KEY (SERVER, INSTANCE_NAME)
  USING INDEX;

  ALTER TABLE AMO.AM_PROG_INSTANCE ADD CONSTRAINT CK_PRIN_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_PROG_INSTANCE MODIFY (SERVER NOT NULL ENABLE);
--------------------------------------------------------
--  Constraints for Table AM_ORACLE_LICENSE_MAPPING
--------------------------------------------------------

  ALTER TABLE AMO.AM_ORACLE_LICENSE_MAPPING ADD CONSTRAINT PK_ORAC_LIC_MAP PRIMARY KEY (CONTRACT_NO, PRODUCT_DESCRIPTION, LICENSED_NAME, LICENSED_TYPE)
  USING INDEX;
--------------------------------------------------------
--  Constraints for Table AM_BACKUP_CONTROL
--------------------------------------------------------

  ALTER TABLE AMO.AM_BACKUP_CONTROL MODIFY (DATABASE_NAME NOT NULL ENABLE);
--------------------------------------------------------
--  Constraints for Table AM_SPACE_THRESHOLD
--------------------------------------------------------

  ALTER TABLE AMO.AM_SPACE_THRESHOLD ADD CONSTRAINT PK_SPTH PRIMARY KEY (SERVER, FILESYSTEM)
  USING INDEX;

  ALTER TABLE AMO.AM_SPACE_THRESHOLD ADD CONSTRAINT THR_ERR_PCT_MONTH CHECK (ERROR_PCT_MONTH>=0 AND ERROR_PCT_MONTH<=100) ENABLE;
  ALTER TABLE AMO.AM_SPACE_THRESHOLD ADD CONSTRAINT THR_ERR_PCT_WEEK CHECK (error_pct_week   BETWEEN 0 AND 100) ENABLE;
  ALTER TABLE AMO.AM_SPACE_THRESHOLD ADD CONSTRAINT THR_ERR_PCT_DAY CHECK (error_pct_day    BETWEEN 0 AND 100) ENABLE;
--------------------------------------------------------
--  Constraints for Table SS_SERVER
--------------------------------------------------------

  ALTER TABLE AMO.SS_SERVER ADD CONSTRAINT CK_SS_SERVER_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.SS_SERVER ADD CONSTRAINT PK_SS_SERVER PRIMARY KEY (SERVER)
  USING INDEX;

--------------------------------------------------------
--  Constraints for Table AM_SCRIPTADD
--------------------------------------------------------

  ALTER TABLE AMO.AM_SCRIPTADD ADD CONSTRAINT CK_SCRIPTADD_TYP CHECK (script_type IN ('CHECK', 'SUMMARY', 'SPECIAL', 'ALL')) ENABLE;
  ALTER TABLE AMO.AM_SCRIPTADD ADD CONSTRAINT CK_SCRADD_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
--------------------------------------------------------
--  Constraints for Table AM_TOTAL_SPACE
--------------------------------------------------------

  ALTER TABLE AMO.AM_TOTAL_SPACE ADD CONSTRAINT PK_AM_TOTAL_SPACE PRIMARY KEY (DATABASE_NAME, SERVER, SPACE_TIME)
  USING INDEX;

--------------------------------------------------------
--  Constraints for Table AM_TABLESPACE_SPACE
--------------------------------------------------------

  ALTER TABLE AMO.AM_TABLESPACE_SPACE ADD CONSTRAINT PK_AM_TABLESPACE_SPACE PRIMARY KEY (DATABASE_NAME, SERVER, TABLESPACE_NAME, SPACE_TIME)
  USING INDEX;

--------------------------------------------------------
--  Constraints for Table AM_DATABASE
--------------------------------------------------------

  ALTER TABLE AMO.AM_DATABASE ADD CONSTRAINT CK_OSC_IND CHECK (os_checks_ind IN ('Y', 'N')) ENABLE;
  ALTER TABLE AMO.AM_DATABASE ADD CONSTRAINT CK_TAL_IND CHECK (tallyman_ind IN ('Y', 'N')) ENABLE;
  ALTER TABLE AMO.AM_DATABASE ADD CONSTRAINT PK_DATA PRIMARY KEY (DATABASE_NAME)
  USING INDEX;

  ALTER TABLE AMO.AM_DATABASE ADD CONSTRAINT CK_DATA_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_DATABASE ADD CONSTRAINT CK_PRD_IND CHECK (production_ind IN ('Y', 'N')) ENABLE;
  ALTER TABLE AMO.AM_DATABASE ADD CONSTRAINT CK_LIC_TYP CHECK (license_type IN ('EE', 'SE', 'SE1', 'SE2')) ENABLE;
  ALTER TABLE AMO.AM_DATABASE MODIFY (DISABLED NOT NULL ENABLE);
  ALTER TABLE AMO.AM_DATABASE MODIFY (DATABASE_NAME NOT NULL ENABLE);
--------------------------------------------------------
--  Constraints for Table AM_SIDSKIP
--------------------------------------------------------

  ALTER TABLE AMO.AM_SIDSKIP ADD CONSTRAINT CK_SKIP_TYPE CHECK (sidskip_type IN (
'DAILY',
'MONDAY', 'TUESDAY', 'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY',
'1', '2', '3', '4', '5', '6', '7', '8', '9', '10', '11', '12', '13', '14', '15', '16',
'17', '18', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31'
)) ENABLE;
  ALTER TABLE AMO.AM_SIDSKIP ADD CONSTRAINT CK_SKIP_MINTO CHECK (minute_to between 0 and 59) ENABLE;
  ALTER TABLE AMO.AM_SIDSKIP ADD CONSTRAINT CK_SKIP_HRTO CHECK (hour_to between 0 and 23) ENABLE;
  ALTER TABLE AMO.AM_SIDSKIP ADD CONSTRAINT CK_SKIP_MINFROM CHECK (minute_from between 0 and 59) ENABLE;
  ALTER TABLE AMO.AM_SIDSKIP ADD CONSTRAINT CK_SKIP_HRFROM CHECK (hour_from between 0 and 23) ENABLE;
  ALTER TABLE AMO.AM_SIDSKIP ADD CONSTRAINT CK_SKIP_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_SIDSKIP MODIFY (DATABASE_NAME NOT NULL ENABLE);

--------------------------------------------------------
--  Constraints for Table AM_METRIC_HIST
--------------------------------------------------------

  ALTER TABLE AMO.AM_METRIC_HIST ADD CONSTRAINT PK_AM_METRIC_HIST PRIMARY KEY (DATABASE_NAME, SERVER, METRIC, SPACE_TIME)
  USING INDEX;
--------------------------------------------------------
--  Constraints for Table AM_PROG_DATABASE
--------------------------------------------------------

  ALTER TABLE AMO.AM_PROG_DATABASE ADD CONSTRAINT PK_PRDA PRIMARY KEY (SERVER, INSTANCE_NAME, PARENT_NAME, DB_NAME)
  USING INDEX;

  ALTER TABLE AMO.AM_PROG_DATABASE ADD CONSTRAINT CK_PRDA_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
  ALTER TABLE AMO.AM_PROG_DATABASE MODIFY (SERVER NOT NULL ENABLE);
--------------------------------------------------------
--  Constraints for Table AM_PROG_SERVER
--------------------------------------------------------

  ALTER TABLE AMO.AM_PROG_SERVER ADD CONSTRAINT CK_AMPS_PRD_IND CHECK (production_ind IN ('Y', 'N')) ENABLE;
  ALTER TABLE AMO.AM_PROG_SERVER MODIFY (PHYSICAL_SERVER NOT NULL ENABLE);
  ALTER TABLE AMO.AM_PROG_SERVER ADD CONSTRAINT PK_AMPS PRIMARY KEY (SERVER)
  USING INDEX;

  ALTER TABLE AMO.AM_PROG_SERVER ADD CONSTRAINT CK_AMPS_DIS CHECK (disabled IN ('N', 'Y')) ENABLE;
--------------------------------------------------------
--  Constraints for Table AM_ORACLE_LICENSE
--------------------------------------------------------

  ALTER TABLE AMO.AM_ORACLE_LICENSE ADD CONSTRAINT CK_LICENSE_TYPE CHECK (licensed_type IN ('C', 'U', 'S')) ENABLE;
--------------------------------------------------------
--  Constraints for Table AM_OS_SPACE
--------------------------------------------------------

  ALTER TABLE AMO.AM_OS_SPACE ADD CONSTRAINT PK_AM_OS_SPACE PRIMARY KEY (SERVER, MOUNTPOINT, SPACE_TIME)
  USING INDEX;

--------------------------------------------------------
--  Ref Constraints for Table AM_ALERT
--------------------------------------------------------

  ALTER TABLE AMO.AM_ALERT ADD CONSTRAINT FK_ALERT_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_ALERT_HISTORY
--------------------------------------------------------

  ALTER TABLE AMO.AM_ALERT_HISTORY ADD CONSTRAINT FK_ALERTHIST_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_DATABASE
--------------------------------------------------------

  ALTER TABLE AMO.AM_DATABASE ADD CONSTRAINT FK_DATABASE_SERVER FOREIGN KEY (SERVER)
	  REFERENCES AMO.AM_SERVER (SERVER) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_METRIC_HIST
--------------------------------------------------------

  ALTER TABLE AMO.AM_METRIC_HIST ADD CONSTRAINT FK_METRICHIST_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_PROG_DATABASE
--------------------------------------------------------

  ALTER TABLE AMO.AM_PROG_DATABASE ADD CONSTRAINT FK_PRDA_PROG FOREIGN KEY (SERVER)
	  REFERENCES AMO.AM_PROG_SERVER (SERVER) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_PROG_INSTANCE
--------------------------------------------------------

  ALTER TABLE AMO.AM_PROG_INSTANCE ADD CONSTRAINT FK_PRIN_PROG FOREIGN KEY (SERVER)
	  REFERENCES AMO.AM_PROG_SERVER (SERVER) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_SCRIPTADD
--------------------------------------------------------

  ALTER TABLE AMO.AM_SCRIPTADD ADD CONSTRAINT FK_SCRADD_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) ENABLE;
  ALTER TABLE AMO.AM_SCRIPTADD ADD CONSTRAINT FK_SCRADD_SCRIPT FOREIGN KEY (SCRIPT_ID)
	  REFERENCES AMO.AM_SCRIPTS (SCRIPT_ID) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_SCRIPTSKIP
--------------------------------------------------------

  ALTER TABLE AMO.AM_SCRIPTSKIP ADD CONSTRAINT FK_SCRSKP_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) ENABLE;
  ALTER TABLE AMO.AM_SCRIPTSKIP ADD CONSTRAINT FK_SCRSKP_SCRIPT FOREIGN KEY (SCRIPT_ID)
	  REFERENCES AMO.AM_SCRIPTS (SCRIPT_ID) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_SCRIPT_SET
--------------------------------------------------------

  ALTER TABLE AMO.AM_SCRIPT_SET ADD CONSTRAINT FK_SCRSET_SCRIPT FOREIGN KEY (SCRIPT_ID)
	  REFERENCES AMO.AM_SCRIPTS (SCRIPT_ID) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_SIDSKIP
--------------------------------------------------------

  ALTER TABLE AMO.AM_SIDSKIP ADD CONSTRAINT FK_SIDSKIP_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_TABLESPACE_SPACE
--------------------------------------------------------

  ALTER TABLE AMO.AM_TABLESPACE_SPACE ADD CONSTRAINT FK_TOTTSPACE_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) DISABLE;
--------------------------------------------------------
--  Ref Constraints for Table AM_TOTAL_SPACE
--------------------------------------------------------

  ALTER TABLE AMO.AM_TOTAL_SPACE ADD CONSTRAINT FK_TOTSPACE_DBNAME FOREIGN KEY (DATABASE_NAME)
	  REFERENCES AMO.AM_DATABASE (DATABASE_NAME) ENABLE;
--------------------------------------------------------
--  Ref Constraints for Table SS_INSTANCE
--------------------------------------------------------

  ALTER TABLE AMO.SS_INSTANCE ADD CONSTRAINT FK_SSIN_SSS FOREIGN KEY (SERVER)
	  REFERENCES AMO.SS_SERVER (SERVER) ENABLE;
--------------------------------------------------------
--  DDL for Function AM_GET_RMAN_DAYS
--------------------------------------------------------

  CREATE OR REPLACE FUNCTION AMO.AM_GET_RMAN_DAYS (
    p_database   am_parameter.param_name%TYPE) RETURN NUMBER
IS
   v_age   NUMBER;
   v_count PLS_INTEGER;
BEGIN

 SELECT COUNT(*)
    INTO v_count
    FROM all_tables
    WHERE table_name = 'AM_BACKUP_CONTROL';

    IF (v_count = 1)
    THEN
        SELECT check_days
        INTO v_age
        FROM (SELECT 0 AS check_days,
                     1 AS order_no
              FROM amo.am_backup_control
              WHERE blackout_from <= sysdate
              AND blackout_to >= sysdate
              AND database_name = p_database
              UNION ALL
              SELECT check_days,
                     2
              FROM amo.am_backup_control
              WHERE blackout_from IS NULL
              AND blackout_to IS NULL
              AND fuzzy_char_before = 'N'
              AND fuzzy_char_after ='N'
              AND database_name = p_database
              UNION ALL
              SELECT check_days,
                     3
              FROM amo.am_backup_control
              WHERE blackout_from IS NULL
              AND blackout_to IS NULL
              AND (fuzzy_char_before = 'Y' OR fuzzy_char_after = 'Y')
              AND p_database LIKE DECODE(fuzzy_char_before,'Y','%','N',NULL) || database_name || DECODE(fuzzy_char_before,'Y','%','N',NULL)
              UNION ALL
              SELECT 1,
                     4
              FROM dual
              ORDER BY 2 ASC)
         WHERE ROWNUM =1;
  ELSE
        v_age :=1;
  END IF;

  RETURN v_age;

EXCEPTION
  WHEN OTHERS THEN
    RETURN 0;
END am_get_rman_days;
 

/

  GRANT EXECUTE ON AMO.AM_GET_RMAN_DAYS TO AMU;
--------------------------------------------------------
--  DDL for Function AM_GET_TS_ALERT_PCT
--------------------------------------------------------
-- 'dual_default' is to avoid a WHEN_NO_DATA_FOUND condition when there are no entries for a server

  CREATE OR REPLACE FUNCTION AMO.AM_GET_TS_ALERT_PCT (
    p_tablespace am_parameter.param_name%TYPE,
    p_database   am_parameter.param_name%TYPE,
    p_server     am_parameter.param_name%TYPE) RETURN NUMBER
IS
   v_return NUMBER;
BEGIN
  WITH
    dual_default AS
        (SELECT 'DUMMY' AS dummy FROM dual),
    server_default AS
        (SELECT 'DUMMY' AS dummy, param_value_num
         FROM   am_parameter
         WHERE param_type = 'SPACE'
         AND   param_name = p_server
         AND   param_parent IS NULL
         AND   param_grand_parent IS NULL),
    database_default AS
        (SELECT 'DUMMY' AS dummy, param_value_num
         FROM   am_parameter
         WHERE  param_type = 'SPACE'
         AND    param_name= p_database
         AND    param_parent = p_tablespace
         AND    param_grand_parent IS NULL),
    tablespace_default AS
        (SELECT 'DUMMY' AS dummy, param_value_num
         FROM   am_parameter
         WHERE  param_type = 'SPACE'
         AND    param_name = p_tablespace
         AND    param_parent = p_database
         AND    param_grand_parent = p_server)
    SELECT NVL(t.param_value_num,NVL(d.param_value_num,NVL(s.param_value_num,95))) INTO v_return
    FROM server_default s,
         database_default d,
         tablespace_default t,
         dual_default z
    WHERE z.dummy = s.dummy (+)
    AND   z.dummy = d.dummy (+)
    AND   z.dummy = t.dummy (+);

  RETURN v_return;

EXCEPTION
  WHEN OTHERS THEN
    RETURN 0;
END am_get_ts_alert_pct;
 

/

  GRANT EXECUTE ON AMO.AM_GET_TS_ALERT_PCT TO AMU;

--------------------------------------------------------
--  DDL for Synonymn AM_VMWARE_SERVER_PREV
--------------------------------------------------------

  CREATE OR REPLACE SYNONYM AMO.AM_VMWARE_SERVER_PREV FOR AMU.AM_VMWARE_SERVER_PREV;

-- Additions from April 2017 

CREATE TABLE amo.am_prog_instskip
   (    server                  VARCHAR2(30 CHAR),
        instance_name           VARCHAR2(30 CHAR),
        skip_type               VARCHAR2(10 CHAR) DEFAULT 'DAILY',
        date_from               DATE,
        date_to                 DATE,
        hour_from               NUMBER(2,0),
        minute_from             NUMBER(2,0),
        hour_to                 NUMBER(2,0),
        minute_to               NUMBER(2,0),
        skip_notes              VARCHAR2(200 CHAR),
        disabled                CHAR(1 CHAR) DEFAULT 'N',
         CONSTRAINT ck_pskip_dis     CHECK (disabled IN ('N', 'Y')),
         CONSTRAINT ck_pskip_hrfrom  CHECK (hour_from BETWEEN 0 and 23),
         CONSTRAINT ck_pskip_minfrom CHECK (minute_from BETWEEN 0 and 59),
         CONSTRAINT ck_pskip_hrto    CHECK (hour_to BETWEEN 0 and 23),
         CONSTRAINT ck_pskip_minto   CHECK (minute_to BETWEEN 0 and 59),
         CONSTRAINT ck_pskip_type    CHECK (skip_type IN ('DAILY', 'MONDAY', 'TUESDAY',
'WEDNESDAY', 'THURSDAY', 'FRIDAY', 'SATURDAY', 'SUNDAY', '1', '2', '3', '4', '5', '6',
'7', '8', '9', '10', '11', '12', '13', '14', '15', '16', '17', '18', '19', '20', '21',
'22', '23', '24', '25', '26', '27', '28', '29', '30', '31')));

COMMENT ON TABLE amo.am_prog_instskip IS 'List of Progress blackouts';

CREATE INDEX amo.ix_psidskip ON amo.am_prog_instskip (SERVER, INSTANCE_NAME, SKIP_TYPE);

GRANT SELECT ON amo.am_prog_instskip TO amu;

