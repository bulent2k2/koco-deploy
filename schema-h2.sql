-- kojojs-editor'ün tables.sql'inden türetilen H2 uyarlaması.
--
-- Özgün dosya bir PostgreSQL KURULUM betiği: CREATE ROLE / CREATE DATABASE /
-- GRANT içeriyor ve elle çalıştırılmak üzere yazılmış. Play evolutions da
-- kurulu değil, yani bellek-içi H2 tamamen BOŞ açılıyordu ve GitHub girişi
-- şununla patlıyordu:
--   JdbcSQLException: Table "user" not found
--
-- Bu dosya H2'nin JDBC URL'indeki INIT=RUNSCRIPT ile bağlantı anında çalışır.
-- Farklar: rol/veritabanı/GRANT satırları yok (H2'de anlamsız), SERIAL yerine
-- AUTO_INCREMENT, "USING BTREE" yok.

CREATE TABLE IF NOT EXISTS "fiddle" (
  "id"            VARCHAR NOT NULL,
  "version"       INTEGER NOT NULL,
  "name"          VARCHAR NOT NULL,
  "description"   VARCHAR NOT NULL,
  "sourcecode"    VARCHAR NOT NULL,
  "libraries"     VARCHAR NOT NULL,
  "scala_version" VARCHAR NOT NULL,
  "user"          VARCHAR NOT NULL,
  "parent"        VARCHAR,
  "created"       BIGINT  NOT NULL,
  "removed"       BOOLEAN NOT NULL,
  CONSTRAINT "pk_fiddle" PRIMARY KEY ("id", "version")
);

CREATE TABLE IF NOT EXISTS "user" (
  "user_id"    VARCHAR NOT NULL,
  "login_info" VARCHAR NOT NULL,
  "first_name" VARCHAR,
  "last_name"  VARCHAR,
  "full_name"  VARCHAR,
  "email"      VARCHAR,
  "avatar_url" VARCHAR,
  "activated"  BOOLEAN NOT NULL,
  CONSTRAINT "pk_user" PRIMARY KEY ("user_id")
);

CREATE TABLE IF NOT EXISTS "access" (
  "id"        INTEGER AUTO_INCREMENT PRIMARY KEY,
  "fiddle_id" VARCHAR NOT NULL,
  "version"   INTEGER NOT NULL,
  "timestamp" BIGINT  NOT NULL,
  "user_id"   VARCHAR,
  "embedded"  BOOLEAN NOT NULL,
  "source_ip" VARCHAR NOT NULL
);

CREATE INDEX IF NOT EXISTS "access_id_idx"   ON "access" ("fiddle_id");
CREATE INDEX IF NOT EXISTS "access_time_idx" ON "access" ("timestamp");
