defmodule WraftDoc.Repo.Migrations.SeedInternalUser do
  use Ecto.Migration

  require Logger

  alias Ecto.Adapters.SQL
  alias WraftDoc.Repo

  @email System.get_env("WRAFT_ADMIN_EMAIL") || "admin@wraft.com"
  @password System.get_env("WRAFT_ADMIN_PASSWORD") || "wraftadmin"

  def up do
    SQL.query!(Repo, internal_user_insert_sql())
  rescue
    error in Postgrex.Error ->
      Logger.error("An error occured while seeding the default internal user.")
      Logger.error(Exception.format(:error, error, __STACKTRACE__))

      reraise error, __STACKTRACE__
  end

  def down do
    SQL.query!(Repo, internal_user_delete_sql())
  rescue
    error in Postgrex.Error ->
      Logger.error("An error occured while deleting the default internal user.")
      Logger.error(Exception.format(:error, error, __STACKTRACE__))

      reraise error, __STACKTRACE__
  end

  defp internal_user_insert_sql do
    encrypted_password = Bcrypt.hash_pwd_salt(@password)
    timestamp = %{NaiveDateTime.utc_now() | microsecond: {0, 0}}

    """
    INSERT INTO internal_user (id, email, encrypted_password, inserted_at, updated_at)
    VALUES ('#{Ecto.UUID.generate()}', '#{@email}', '#{encrypted_password}', '#{timestamp}', '#{timestamp}');
    """
  end

  defp internal_user_delete_sql do
    "DELETE FROM internal_user WHERE email='#{@email}';"
  end
end
