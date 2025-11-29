defmodule WraftDoc.Repo.Migrations.EnsureMetaInContentTypeField do
  use Ecto.Migration

  def up do
    # Check if meta column exists, if not add it
    execute("""
      DO $$
      BEGIN
        IF NOT EXISTS (
          SELECT 1 
          FROM information_schema.columns 
          WHERE table_name = 'content_type_field' 
          AND column_name = 'meta'
        ) THEN
          ALTER TABLE content_type_field ADD COLUMN meta jsonb DEFAULT '{}'::jsonb;
        ELSE
          -- Column exists, just set default and update NULL values
          ALTER TABLE content_type_field ALTER COLUMN meta SET DEFAULT '{}'::jsonb;
          UPDATE content_type_field SET meta = '{}'::jsonb WHERE meta IS NULL;
        END IF;
      END $$;
    """)
  end

  def down do
    execute("""
      ALTER TABLE content_type_field ALTER COLUMN meta DROP DEFAULT;
    """)
  end
end
