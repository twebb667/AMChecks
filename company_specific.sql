ALTER TABLE amo.am_database ADD (license_type varchar2(3));
ALTER TABLE amo.am_database ADD (CONSTRAINT ck_lic_typ CHECK (license_type IN ('EE', 'SE', 'SE1', 'SE2')));
COMMENT ON COLUMN amo.am_database.license_type IS  'Enterprise Edition Standard Edition and other flavours';

ALTER TABLE amo.am_database ADD (tallyman_ind CHAR(1));
ALTER TABLE amo.am_database ADD (CONSTRAINT ck_tal_ind CHECK (tallyman_ind IN ('Y', 'N')));

ALTER TABLE amo.am_database ADD (production_ind CHAR(1));
ALTER TABLE amo.am_database ADD (CONSTRAINT ck_prd_ind CHECK (production_ind IN ('Y', 'N')));

ALTER TABLE amo.am_database ADD (support_level NUMBER(2));
COMMENT ON COLUMN amo.am_database.support_level IS  'Number used to represent importance eg GOLD SILVER BRONZE or SLA value';

ALTER TABLE amo.am_database ADD (comments varchar2(4000));
COMMENT ON COLUMN amo.am_database.comments IS  'Notes relating to the database';

ALTER TABLE amo.am_database ADD (os_checks_ind CHAR(1) DEFAULT 'N');
ALTER TABLE amo.am_database ADD (CONSTRAINT ck_osc_ind CHECK (os_checks_ind IN ('Y', 'N')));
COMMENT ON COLUMN amo.am_database.os_checks_ind IS  'Run OS Space checks from this database';
