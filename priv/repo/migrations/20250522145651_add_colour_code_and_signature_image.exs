defmodule WraftDoc.Repo.Migrations.AddColourCodeAndSignatureImage do
  use Ecto.Migration

  def change do
    alter table(:counter_parties) do
      add(:color_rgb, :map)
      add(:signature_image, :string)
    end
  end
end
