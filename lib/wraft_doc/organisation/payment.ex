defmodule WraftDoc.Enterprise.Membership.Payment do
  @moduledoc """
  The payment model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  use Arc.Ecto.Schema
  alias __MODULE__
  require Protocol
  Protocol.derive(Jason.Encoder, Razorpay.Payment)
  def statuses(), do: [failed: 1, captured: 2]
  def actions(), do: [downgrade: 1, renew: 2, upgrade: 3]

  schema "payment" do
    field(:uuid, Ecto.UUID, autogenerate: true)
    field(:razorpay_id, :string)
    field(:start_date, :naive_datetime)
    field(:end_date, :naive_datetime)
    field(:invoice, WraftDocWeb.InvoiceUploader.Type)
    field(:invoice_number, :string)
    field(:amount, :float)
    field(:action, :integer)
    field(:status, :integer)
    field(:meta, :map)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:membership, WraftDoc.Enterprise.Membership)
    belongs_to(:from_plan, WraftDoc.Enterprise.Plan)
    belongs_to(:to_plan, WraftDoc.Enterprise.Plan)

    timestamps()
  end

  def changeset(%Payment{} = payment, attrs \\ %{}) do
    payment
    |> cast(attrs, [
      :razorpay_id,
      :start_date,
      :end_date,
      :amount,
      :action,
      :status,
      :organisation_id,
      :creator_id,
      :membership_id,
      :from_plan_id,
      :to_plan_id,
      :meta
    ])
    |> validate_required([:razorpay_id, :amount, :status])
    |> unique_constraint(:razorpay_id,
      name: :razorpay_id_unique_index,
      message: "Something Wrong. Try again.!"
    )
  end

  def invoice_changeset(%Payment{} = payment, attrs \\ %{}) do
    payment
    |> cast(attrs, [:invoice_number])
    |> cast_attachments(attrs, [:invoice])
    |> validate_required([:invoice, :invoice_number])
    |> unique_constraint(:invoice_number,
      name: :invoice_number_unique_index,
      message: "Wrong invoice number.!"
    )
  end
end
