-- Convert schema '/home/frank/github/kanku/share/migrations/_source/deploy/18/001-auto.yml' to '/home/frank/github/kanku/share/migrations/_source/deploy/17/001-auto.yml':;

;
BEGIN;

;
CREATE TEMPORARY TABLE job_history_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  name text,
  state text,
  args text,
  result text,
  creation_time integer DEFAULT 0,
  start_time integer DEFAULT 0,
  end_time integer DEFAULT 0,
  last_modified integer DEFAULT 0,
  workerinfo text,
  masterinfo text,
  trigger_user text,
  pwrand text
);

;
INSERT INTO job_history_temp_alter( id, name, state, args, result, creation_time, start_time, end_time, last_modified, workerinfo, masterinfo, trigger_user, pwrand) SELECT id, name, state, args, result, creation_time, start_time, end_time, last_modified, workerinfo, masterinfo, trigger_user, pwrand FROM job_history;

;
DROP TABLE job_history;

;
CREATE TABLE job_history (
  id INTEGER PRIMARY KEY NOT NULL,
  name text,
  state text,
  args text,
  result text,
  creation_time integer DEFAULT 0,
  start_time integer DEFAULT 0,
  end_time integer DEFAULT 0,
  last_modified integer DEFAULT 0,
  workerinfo text,
  masterinfo text,
  trigger_user text,
  pwrand text
);

;
INSERT INTO job_history SELECT id, name, state, args, result, creation_time, start_time, end_time, last_modified, workerinfo, masterinfo, trigger_user, pwrand FROM job_history_temp_alter;

;
DROP TABLE job_history_temp_alter;

;
CREATE TEMPORARY TABLE job_history_sub_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  job_id integer,
  name text,
  state text,
  result text,
  FOREIGN KEY (job_id) REFERENCES job_history(id) ON DELETE CASCADE ON UPDATE NO ACTION
);

;
INSERT INTO job_history_sub_temp_alter( id, job_id, name, state, result) SELECT id, job_id, name, state, result FROM job_history_sub;

;
DROP TABLE job_history_sub;

;
CREATE TABLE job_history_sub (
  id INTEGER PRIMARY KEY NOT NULL,
  job_id integer,
  name text,
  state text,
  result text,
  FOREIGN KEY (job_id) REFERENCES job_history(id) ON DELETE CASCADE ON UPDATE NO ACTION
);

;
CREATE INDEX job_history_sub_idx_job_id02 ON job_history_sub (job_id);

;
INSERT INTO job_history_sub SELECT id, job_id, name, state, result FROM job_history_sub_temp_alter;

;
DROP TABLE job_history_sub_temp_alter;

;
DROP INDEX job_wait_for_fk_job_id;

;
DROP INDEX job_wait_for_fk_wait_for_job_id;

;

;

;
DROP TABLE job_group;

;

COMMIT;

