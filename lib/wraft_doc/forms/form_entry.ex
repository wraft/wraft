defmodule WraftDoc.Forms.FormEntry do
  @moduledoc """
  form entry  model.
  """
  alias __MODULE__
  use WraftDoc.Schema

  @fields [:data, :status, :form_id, :user_id]

  schema "form_entry" do
    field(:data, :map)
    field(:status, Ecto.Enum, values: [:submitted, :draft])
    belongs_to(:form, WraftDoc.Forms.Form)
    belongs_to(:user, WraftDoc.Account.User)

    timestamps()
  end

  def changeset(%FormEntry{} = form_entry, params \\ %{}) do
    form_entry
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> foreign_key_constraint(:form_id, message: "Please enter an existing form")
    |> foreign_key_constraint(:user_id, message: "Please enter an existing user")
  end
end
