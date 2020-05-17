defmodule WraftDoc.Repo.Migrations.CreateESignature do
  use Ecto.Migration

  def change do
    create table(:e_signature) do
      add(:uuid, :uuid, null: false)
      add(:api_url, :string, null: false)
      add(:body, :string, null: false)
      add(:header, :string)
      add(:file, :string)
      add(:signed_file, :string)
      add(:content_id, references(:content, on_delete: :nilify_all))
      add(:user_id, references(:user, on_delete: :nilify_all))
      add(:organisation_id, references(:organisation, on_delete: :nilify_all))
      timestamps()
    end
  end
end
