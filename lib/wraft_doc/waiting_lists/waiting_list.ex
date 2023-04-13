defimpl FunWithFlags.Actor, for: Map do
  def id(%{email: email}) do
    "email:#{email}"
  end
end

defmodule WraftDoc.WaitingLists.WaitingList do
  @moduledoc """
  The waiting_list model.
  """
  use WraftDoc.Schema
  alias __MODULE__

  schema "waiting_list" do
    field(:first_name, :string)
    field(:last_name, :string)
    field(:email, :string)
    field(:status, Ecto.Enum, values: [:approved, :rejected, :pending], default: :pending)

    timestamps()
  end

  def changeset(%WaitingList{} = waiting_list, attrs \\ %{}) do
    waiting_list
    |> cast(attrs, [:first_name, :last_name, :email, :status])
    |> validate_required([:first_name, :last_name, :email, :status])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "invalid email")
    |> unique_constraint(:email,
      message: "User with this email already in waiting list.",
      name: :waiting_list_email_index
    )
  end
end
