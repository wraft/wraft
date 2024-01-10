defmodule WraftDoc.Repo.Migrations.AddOban do
  @moduledoc """
  Migration for Oban
  """
  use Ecto.Migration

  def up, do: Oban.Migrations.up()

  def down, do: Oban.Migrations.down()
end
