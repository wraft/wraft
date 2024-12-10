defmodule WraftDoc.Account.GuestUser do
  @moduledoc """
  The guest user model.
  """
  use WraftDoc.Schema

  schema "guest_user" do
    field(:email, :string)
    timestamps()
  end

  def changeset(guest_user, attrs \\ %{}) do
    guest_user
    |> cast(attrs, [:email])
    |> validate_required([:email])
    |> validate_format(:email, ~r/@/)
    |> unique_constraint(:email,
      message: "Email already taken.! Try another email.",
      name: :guest_user_email_index
    )
  end
end
