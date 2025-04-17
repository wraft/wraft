defmodule WraftDoc.Schema do
  @moduledoc """
   Schema Macro
  """
  alias WraftDoc.Account.User
  alias WraftDoc.Account.UserOrganisation
  alias WraftDoc.Repo
  import Ecto.Changeset
  import Ecto.Query

  defmacro __using__(_) do
    quote do
      use Ecto.Schema
      import WraftDoc.Schema
      import Ecto.Changeset
      @primary_key {:id, :binary_id, autogenerate: true}
      @foreign_key_type :binary_id
      @derive {Phoenix.Param, key: :id}
    end
  end

  # Helper function to decode JSON values
  def decode_json_value(val) when is_binary(val), do: Jason.decode!(val)

  def decode_json_value(val), do: val

  defmacro decode_json_fields(attrs_ast, fields) do
    quote do
      Enum.reduce(unquote(fields), unquote(attrs_ast), fn field, acc ->
        Map.update(acc, to_string(field), nil, &WraftDoc.Schema.decode_json_value(&1))
      end)
    end
  end

  def generate_encrypted_password(current_changeset) do
    case current_changeset do
      %Ecto.Changeset{valid?: true, changes: %{password: password}} ->
        put_change(
          current_changeset,
          :encrypted_password,
          Bcrypt.hash_pwd_salt(password)
        )

      _ ->
        current_changeset
    end
  end

  def organisation_constraint(changeset, schema, field, opts \\ []) do
    organisation_id =
      get_field(changeset, :organisation_id) || changeset.params["organisation_id"]

    case is_nil(organisation_id) do
      false ->
        schema_id = get_change(changeset, field)
        check_organisation_constraint(changeset, organisation_id, schema, schema_id, field, opts)

      true ->
        add_error(changeset, :organisation_id, "params must contain organisation id")
    end
  end

  defp check_organisation_constraint(changeset, _org_id, _schema, schema_id, _field, _opts)
       when is_nil(schema_id) do
    changeset
  end

  defp check_organisation_constraint(changeset, organisation_id, schema, schema_id, field, opts) do
    message = Keyword.get(opts, :message, "is invalid")
    data = get_data(schema, schema_id, organisation_id)

    if is_nil(data) do
      add_error(changeset, field, message)
    else
      changeset
    end
  end

  defp get_data(User, id, organisation_id) do
    User
    |> where([u], u.id == ^id)
    |> join(:inner, [u], uo in UserOrganisation, on: uo.user_id == u.id, as: :user_org)
    |> where([user_org: uo], uo.organisation_id == ^organisation_id)
    |> Repo.one()
  end

  defp get_data(schema, id, organisation_id) do
    Repo.get_by(schema, id: id, organisation_id: organisation_id)
  end
end
