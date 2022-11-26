-- Convert schema '/home/frank/github/kanku/share/migrations/_source/deploy/17/001-auto.yml' to '/home/frank/github/kanku/share/migrations/_source/deploy/18/001-auto.yml':;

;
BEGIN;

;
CREATE TABLE "job_group" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "name" text,
  "creation_time" integer DEFAULT 0,
  "start_time" integer DEFAULT 0,
  "end_time" integer DEFAULT 0
);

;
ALTER TABLE job_history ADD COLUMN job_group_id integer;

;
CREATE INDEX job_history_idx_job_group_id ON job_history (job_group_id);

;

;
ALTER TABLE job_history_sub ADD COLUMN start_time integer;

;
ALTER TABLE job_history_sub ADD COLUMN end_time integer;

;

;

;

COMMIT;

