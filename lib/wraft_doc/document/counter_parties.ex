defmodule WraftDoc.Document.CounterParties do
  @moduledoc """
    This is the Counter Parties module
  """
  use WraftDoc.Schema

  schema "counter_parties" do
    field(:name, :string)
    belongs_to(:content, WraftDoc.Document.Instance)
    # TODO replace it with user schema
    # belongs_to(:guest_user, WraftDoc.Account.GuestUser)
    timestamps()
  end

  def changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:name, :content_id, :guest_user_id])
    |> validate_required([:name, :content_id, :guest_user_id])
    |> unique_constraint([:content_id, :guest_user_id], message: "already exist")
  end
end
