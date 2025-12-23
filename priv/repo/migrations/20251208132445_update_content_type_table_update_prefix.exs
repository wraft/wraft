defmodule WraftDoc.Repo.Migrations.FixDuplicatePrefixesWithNumericSuffix do
  use Ecto.Migration

  def up do
    execute("""
    WITH duplicates AS (
      SELECT
        id,
        prefix,
        organisation_id,
        inserted_at,
        ROW_NUMBER() OVER (
          PARTITION BY organisation_id, prefix
          ORDER BY inserted_at
        ) AS row_num
      FROM content_type
    )
    UPDATE content_type AS ct
    SET prefix = d.prefix || (d.row_num - 1)
    FROM duplicates d
    WHERE ct.id = d.id
      AND d.row_num > 1;
    """)

    create(
      unique_index(:content_type, [:organisation_id, :prefix], name: :unique_org_prefix_index)
    )
  end

  def down do
    drop_if_exists(
      index(:content_type, [:organisation_id, :prefix], name: :unique_org_prefix_index)
    )
  end
end
