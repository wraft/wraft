defmodule WraftDoc.InvitedUsers.InvitedUser do
  @moduledoc """
  Schema for invited users.
  """
  use WraftDoc.Schema

  @statuses ~w(invited joined expired)

  schema "invited_user" do
    field(:email, :string)
    field(:status, :string, default: "invited")

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    many_to_many(:roles, WraftDoc.Account.Role,
      join_through: "invited_users_roles",
      on_replace: :delete
    )

    timestamps()
  end

  def changeset(invited_user, attrs \\ %{}) do
    invited_user
    |> cast(attrs, [:email, :status, :organisation_id])
    |> validate_required([:email, :organisation_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "has invalid format")
    |> unique_constraint(
      :email,
      message: "user already invited",
      name: :invited_user_email_organisation_id_index
    )
    |> validate_inclusion(:status, @statuses)
  end

  def status_changeset(invited_user, attrs \\ %{}) do
    invited_user
    |> cast(attrs, [:status])
    |> validate_inclusion(:status, @statuses)
  end
end
