-- Convert schema '/home/frank/gh/M0ses/kanku/share/migrations/_source/deploy/18/001-auto.yml' to '/home/frank/gh/M0ses/kanku/share/migrations/_source/deploy/19/001-auto.yml':;

;
BEGIN;

;
CREATE TEMPORARY TABLE obs_check_history_temp_alter (
  id INTEGER PRIMARY KEY NOT NULL,
  obsurl text,
  project text,
  package text,
  vm_image_url text,
  check_time integer
);

;
INSERT INTO obs_check_history_temp_alter( id, project, package, vm_image_url, check_time) SELECT id, project, package, vm_image_url, check_time FROM obs_check_history;

;
DROP TABLE obs_check_history;

;
CREATE TABLE obs_check_history (
  id INTEGER PRIMARY KEY NOT NULL,
  obsurl text,
  project text,
  package text,
  vm_image_url text,
  check_time integer
);

;
CREATE UNIQUE INDEX obsurl_project_package_uniq00 ON obs_check_history (obsurl, project, package);

;
INSERT INTO obs_check_history SELECT id, obsurl, project, package, vm_image_url, check_time FROM obs_check_history_temp_alter;

;
DROP TABLE obs_check_history_temp_alter;

;

COMMIT;

