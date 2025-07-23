defmodule WraftDoc.CounterParties.CounterParty do
  @moduledoc """
    This is the Counter Parties module for managing document signatories.

    Counter parties can be categorized by party_type (external, vendor, current_org)
    and can sign documents using different signature_type methods (electronic, digital, zoho_sign, docusign).
    The sign_order field determines the sequence in which counterparties should sign the document.
  """
  use Waffle.Ecto.Schema
  use WraftDoc.Schema

  @signature_status [:pending, :accepted, :signed]
  @party_types [:external, :vendor, :current_org]
  @signature_types [:electronic, :digital, :zoho_sign, :docusign]

  schema "counter_parties" do
    field(:name, :string)
    field(:email, :string)
    field(:signature_status, Ecto.Enum, values: @signature_status, default: :pending)
    field(:signature_date, :utc_datetime)
    field(:signature_ip, :string)
    field(:device, :string)
    field(:signature_image, WraftDocWeb.SignatureUploader.Type)
    field(:signed_file, :string)
    field(:color_rgb, :map)
    field(:party_type, Ecto.Enum, values: @party_types)
    field(:signature_type, Ecto.Enum, values: @signature_types)
    field(:sign_order, :integer)
    has_many(:e_signature, WraftDoc.Documents.ESignature)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:party_type_ref, WraftDoc.CounterParties.PartyType, foreign_key: :party_type_id)

    timestamps()
  end

  def changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [
      :name,
      :email,
      :content_id,
      :user_id,
      :signature_status,
      :signature_date,
      :signature_ip,
      :color_rgb,
      :party_type,
      :signature_type,
      :sign_order,
      :party_type_id
    ])
    |> validate_required([:name, :content_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:user_id,
      name: :counter_parties_user_id_content_id_index,
      message: "Counterparty already exists for this document"
    )
    |> validate_color_rgb()
    |> validate_number(:sign_order, greater_than: 0)
  end

  def update_status_changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:signature_status])
    |> validate_required([:signature_status])
  end

  def sign_changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:signature_status, :signature_date, :signature_ip, :signed_file, :device])
    |> cast_attachments(attrs, [:signature_image])
    |> validate_required([:signature_status, :signature_date, :signature_image, :device])
  end

  def update_counterparty(counterparty, attrs) do
    counterparty
    |> cast(attrs, [:signed_file])
    |> validate_required([:signed_file])
  end

  defp validate_color_rgb(changeset) do
    changeset
    |> get_field(:color_rgb)
    |> validate_color_rgb_values(changeset)
  end

  defp validate_color_rgb_values(nil, changeset), do: changeset

  defp validate_color_rgb_values(%{"r" => r, "g" => g, "b" => b} = _color_rgb, changeset)
       when r in 200..255 and g in 200..255 and b in 200..255,
       do: changeset

  defp validate_color_rgb_values(_invalid_color_rgb, changeset) do
    add_error(
      changeset,
      :color_rgb,
      "must be a map with keys r, g, b and values between 200 and 255"
    )
  end
end
