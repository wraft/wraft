defmodule WraftDoc.Repo.Migrations.SeedCountries do
  use Ecto.Migration

  @file_path :wraft_doc |> :code.priv_dir() |> Path.join("repo/data/countries.json")

  def up do
    countries =
      @file_path
      |> File.read!()
      |> Jason.decode!()

    countries
    |> Stream.map(fn country ->
      execute("""
      INSERT INTO country (id, country_name, country_code, calling_code, inserted_at, updated_at)
      VALUES (gen_random_uuid(), '#{country["name"]}', '#{country["code"]}', '#{country["dial_code"]}', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      """)
    end)
    |> Enum.to_list()
  end

  def down do
    execute("DELETE FROM country")
  end
end
