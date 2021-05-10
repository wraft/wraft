defmodule WraftDoc.Repo.Migrations.CreateESignature do
  use Ecto.Migration

  def change do
    create table(:e_signature, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:api_url, :string, null: false)
      add(:body, :string, null: false)
      add(:header, :string)
      add(:file, :string)
      add(:signed_file, :string)
      add(:content_id, references(:content, type: :uuid, column: :id, on_delete: :nilify_all))
      add(:user_id, references(:user, type: :uuid, column: :id, on_delete: :nilify_all))

      add(
        :organisation_id,
        references(:organisation, type: :uuid, column: :id, on_delete: :nilify_all)
      )

      timestamps()
    end
  end
end
