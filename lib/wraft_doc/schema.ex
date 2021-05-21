defmodule WraftDoc.Schema do
  @moduledoc """
   Schema Macro
  """
  alias WraftDoc.Repo
  import Ecto.Changeset

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import Ecto.Query
      import WraftDoc.Schema
      import Ecto.Changeset
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @derive {Phoenix.Param, key: :id}
    end
  end

  def organisation_constraint(
        %Ecto.Changeset{params: %{"organisation_id" => organisation_id}} = changeset,
        schema,
        field
      ) do
    cond do
      is_nil(changeset.changes[field]) ->
        changeset

      is_nil(Repo.get_by(schema, id: changeset.changes[field], organisation_id: organisation_id)) ->
        add_error(changeset, field, "Invalid #{field}")

      true ->
        changeset
    end
  end

  def organisation_constraint(changeset, _schema, _field) do
    add_error(changeset, :organisation_id, "params must contain organisation id")
  end
end
