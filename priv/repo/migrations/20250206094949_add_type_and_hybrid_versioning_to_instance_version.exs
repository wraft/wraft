defmodule WraftDoc.Repo.Migrations.AddTypeAndHybridVersioningToInstanceVersion do
  use Ecto.Migration

  def up do
    alter table(:version) do
      add(:type, :string)
      modify(:version_number, :string, null: false, from: :integer, null: false)
    end

    # Mark all existing records as "build"
    execute("UPDATE version SET type = 'build' WHERE type IS NULL")

    # Convert version_number to "save:0,build:<existing_number>"
    execute(
      "UPDATE version SET version_number = 'save:0,build:' || version_number WHERE type = 'build'"
    )
  end

  def down do
    # Extract the numeric part from version_number
    execute("""
      UPDATE version
      SET version_number = REGEXP_REPLACE(version_number, '^save:0,build:', '', 'g')
    """)

    # Ensure all version_number values are valid integers
    execute("""
      ALTER TABLE version
      ALTER COLUMN version_number
      SET DATA TYPE INTEGER
      USING version_number::INTEGER
    """)

    # Remove the 'type' column
    execute("ALTER TABLE version DROP COLUMN type")
  end
end
