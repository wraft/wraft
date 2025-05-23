defmodule WraftDoc.CounterParties.CounterParty do
  @moduledoc """
    This is the Counter Parties module for managing document signatories
  """
  use Waffle.Ecto.Schema
  use WraftDoc.Schema

  @signature_status [:pending, :accepted, :signed, :rejected]

  schema "counter_parties" do
    field(:name, :string)
    field(:email, :string)
    field(:signature_status, Ecto.Enum, values: @signature_status, default: :pending)
    field(:signature_date, :utc_datetime)
    field(:signature_ip, :string)
    field(:signature_image, WraftDocWeb.SignatureUploader.Type)
    field(:color_rgb, :map)
    has_many(:e_signature, WraftDoc.Documents.ESignature)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:user, WraftDoc.Account.User)

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
      :color_rgb
    ])
    |> validate_required([:name, :content_id])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must have the @ sign and no spaces")
    |> unique_constraint(:user_id,
      name: :counter_parties_user_id_content_id_index,
      message: "Counterparty already exists for this document"
    )
    |> validate_color_rgb()
  end

  def update_status_changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:signature_status])
    |> validate_required([:signature_status])
  end

  def sign_changeset(counter_parties, attrs) do
    counter_parties
    |> cast(attrs, [:signature_status, :signature_date, :signature_ip, :signature_image])
    |> validate_required([:signature_status, :signature_date])
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
