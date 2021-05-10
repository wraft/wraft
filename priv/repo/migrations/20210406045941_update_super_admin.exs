defmodule WraftDoc.Repo.Migrations.UpdateSuperAdmin do
  use Ecto.Migration

  def up do
    execute("""
    UPDATE role SET name = 'super_admin' WHERE name='admin'
    """)
  end

  def down do
    execute("""
    UPDATE role SET name = 'admin' WHERE name='super_admin'
    """)
  end
end
