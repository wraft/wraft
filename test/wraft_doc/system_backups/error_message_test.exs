defmodule WraftDoc.SystemBackups.ErrorMessageTest do
  use ExUnit.Case, async: true

  alias WraftDoc.SystemBackups.ErrorMessage

  test "nil and empty errors stay nil" do
    assert ErrorMessage.humanize(nil) == nil
    assert ErrorMessage.humanize("") == nil
  end

  test "MinIO storage-full upload errors read as out-of-disk" do
    raw =
      "upload of system/backups/7dcc34ef/database.dump failed: {:http_error, 507, " <>
        "\"<Error><Code>XMinioStorageFull</Code><Message>Storage backend has reached " <>
        "its minimum free drive threshold.</Message></Error>\"}"

    assert ErrorMessage.humanize(raw) =~ "out of disk space"
  end

  test "storage-full beats the generic upload message" do
    refute ErrorMessage.humanize("upload of x failed: XMinioStorageFull") =~ "Uploading"
  end

  test "missing bucket" do
    assert ErrorMessage.humanize("upload of x failed: NoSuchBucket") =~ "bucket does not exist"
  end

  test "unreachable storage" do
    assert ErrorMessage.humanize("upload of x failed: {:error, :econnrefused}") =~
             "Could not reach the storage server"
  end

  test "generic upload failure" do
    assert ErrorMessage.humanize("upload of system/backups/x/bucket.tar failed: weird") ==
             "Uploading the backup to the storage server failed."
  end

  test "configuration errors name the env var" do
    assert ErrorMessage.humanize("no backup bucket configured (MINIO_BACKUP_BUCKET)") =~
             "MINIO_BACKUP_BUCKET"
  end

  test "staging disk pre-flight" do
    assert ErrorMessage.humanize(
             "insufficient disk for backup staging: 100 bytes free, 2000000000 required"
           ) =~ "Not enough free disk space on the app server"
  end

  test "pg_dump failures read as database export" do
    assert ErrorMessage.humanize("pg_dump failed (exit 1): connection refused") =~
             "Exporting the database failed"
  end

  test "restore failures" do
    assert ErrorMessage.humanize("pg_restore failed (exit 1): boom") =~
             "Loading the database from the backup failed"

    assert ErrorMessage.humanize("createdb failed (exit 1): boom") =~
             "Could not create the new database"

    assert ErrorMessage.humanize("download of system/backups/x/bucket.tar failed: y") =~
             "Downloading the backup"
  end

  test "unknown errors get the generic fallback, never raw detail" do
    message = ErrorMessage.humanize("some brand new {:weird, :tuple} failure")
    assert message =~ "Something went wrong"
    refute message =~ "tuple"
  end
end
