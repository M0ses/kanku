--
-- Created by SQL::Translator::Producer::SQLite
-- Created on Fri Nov 25 12:04:41 2022
--

;
BEGIN TRANSACTION;
--
-- Table: "image_download_history"
--
CREATE TABLE "image_download_history" (
  "vm_image_url" text NOT NULL,
  "vm_image_file" text,
  "download_time" integer,
  "etag" text,
  "project" text,
  "package" text,
  "repository" text,
  "arch" text,
  PRIMARY KEY ("vm_image_url")
);
--
-- Table: "job_group"
--
CREATE TABLE "job_group" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "name" text,
  "creation_time" integer DEFAULT 0,
  "start_time" integer DEFAULT 0,
  "end_time" integer DEFAULT 0
);
--
-- Table: "obs_check_history"
--
CREATE TABLE "obs_check_history" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "api_url" text,
  "project" text,
  "package" text,
  "vm_image_url" text,
  "check_time" integer
);
CREATE UNIQUE INDEX "api_url_project_package_unique" ON "obs_check_history" ("api_url", "project", "package");
--
-- Table: "role"
--
CREATE TABLE "role" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "role" varchar(32) NOT NULL
);
--
-- Table: "state_worker"
--
CREATE TABLE "state_worker" (
  "hostname" varchar(256) NOT NULL,
  "last_seen" integer NOT NULL,
  "last_update" integer NOT NULL,
  "info" text NOT NULL,
  PRIMARY KEY ("hostname")
);
--
-- Table: "user"
--
CREATE TABLE "user" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "username" varchar(32) NOT NULL,
  "password" varchar(40),
  "name" varchar(128),
  "email" varchar(255),
  "deleted" boolean NOT NULL DEFAULT 0,
  "lastlogin" datetime,
  "pw_changed" datetime,
  "pw_reset_code" varchar(255)
);
CREATE UNIQUE INDEX "user_username" ON "user" ("username");
--
-- Table: "ws_session"
--
CREATE TABLE "ws_session" (
  "session_token" varchar(32) NOT NULL,
  "user_id" integer NOT NULL,
  "permissions" integer NOT NULL,
  "filters" text NOT NULL,
  PRIMARY KEY ("session_token")
);
--
-- Table: "job_history"
--
CREATE TABLE "job_history" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "name" text,
  "state" text,
  "args" text,
  "result" text,
  "creation_time" integer DEFAULT 0,
  "start_time" integer DEFAULT 0,
  "end_time" integer DEFAULT 0,
  "last_modified" integer DEFAULT 0,
  "workerinfo" text,
  "masterinfo" text,
  "trigger_user" text,
  "pwrand" text,
  "job_group_id" integer,
  FOREIGN KEY ("job_group_id") REFERENCES "job_group"("id")
);
CREATE INDEX "job_history_idx_job_group_id" ON "job_history" ("job_group_id");
--
-- Table: "role_request"
--
CREATE TABLE "role_request" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "user_id" integer NOT NULL,
  "creation_time" integer NOT NULL,
  "roles" text NOT NULL,
  "comment" text NOT NULL,
  "decision" integer NOT NULL DEFAULT 0,
  "decision_comment" text NOT NULL,
  FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "role_request_idx_user_id" ON "role_request" ("user_id");
--
-- Table: "ws_token"
--
CREATE TABLE "ws_token" (
  "user_id" integer NOT NULL,
  "auth_token" varchar(32) NOT NULL,
  PRIMARY KEY ("auth_token"),
  FOREIGN KEY ("user_id") REFERENCES "user"("id")
);
CREATE INDEX "ws_token_idx_user_id" ON "ws_token" ("user_id");
--
-- Table: "job_history_sub"
--
CREATE TABLE "job_history_sub" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "job_id" integer,
  "name" text,
  "state" text,
  "result" text,
  "start_time" integer,
  "end_time" integer,
  FOREIGN KEY ("job_id") REFERENCES "job_history"("id") ON DELETE CASCADE ON UPDATE NO ACTION
);
CREATE INDEX "job_history_sub_idx_job_id" ON "job_history_sub" ("job_id");
--
-- Table: "job_wait_for"
--
CREATE TABLE "job_wait_for" (
  "job_id" integer NOT NULL,
  "wait_for_job_id" integer NOT NULL,
  PRIMARY KEY ("job_id", "wait_for_job_id"),
  FOREIGN KEY ("job_id") REFERENCES "job_history"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("wait_for_job_id") REFERENCES "job_history"("id")
);
CREATE INDEX "job_wait_for_idx_job_id" ON "job_wait_for" ("job_id");
CREATE INDEX "job_wait_for_idx_wait_for_job_id" ON "job_wait_for" ("wait_for_job_id");
--
-- Table: "user_roles"
--
CREATE TABLE "user_roles" (
  "user_id" integer NOT NULL,
  "role_id" integer NOT NULL,
  PRIMARY KEY ("user_id", "role_id"),
  FOREIGN KEY ("role_id") REFERENCES "role"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  FOREIGN KEY ("user_id") REFERENCES "user"("id") ON DELETE CASCADE ON UPDATE CASCADE
);
CREATE INDEX "user_roles_idx_role_id" ON "user_roles" ("role_id");
CREATE INDEX "user_roles_idx_user_id" ON "user_roles" ("user_id");
--
-- Table: "job_history_comment"
--
CREATE TABLE "job_history_comment" (
  "id" INTEGER PRIMARY KEY NOT NULL,
  "job_id" integer,
  "user_id" integer,
  "comment" text,
  FOREIGN KEY ("job_id") REFERENCES "job_history"("id") ON DELETE CASCADE ON UPDATE NO ACTION,
  FOREIGN KEY ("user_id") REFERENCES "user"("id")
);
CREATE INDEX "job_history_comment_idx_job_id" ON "job_history_comment" ("job_id");
CREATE INDEX "job_history_comment_idx_user_id" ON "job_history_comment" ("user_id");
COMMIT;
