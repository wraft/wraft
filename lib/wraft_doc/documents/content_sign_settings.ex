defmodule WraftDoc.Documents.ContentSignSettings do
  @moduledoc """
  Embedded schema for content sign settings that control signature behavior for documents.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @signature_types ["e_sign", "digital", "docusign", "zoho_sign"]

  @primary_key false
  embedded_schema do
    field(:signature_type, :string, default: "e_sign")
    field(:sign_order_enabled, :boolean, default: false)
    field(:day_to_complete, :string, default: "15")
    field(:reminder_enabled, :boolean, default: true)
    field(:reminder_interval_days, :integer, default: 3)
    field(:cc_recipients, {:array, :map}, default: [])
  end

  def changeset(content_sign_settings, attrs \\ %{}) do
    content_sign_settings
    |> cast(attrs, [
      :signature_type,
      :sign_order_enabled,
      :day_to_complete,
      :reminder_enabled,
      :reminder_interval_days,
      :cc_recipients
    ])
    |> validate_inclusion(:signature_type, @signature_types)
    |> validate_number(:reminder_interval_days, greater_than: 0)
    |> validate_cc_recipients()
  end

  defp validate_cc_recipients(changeset) do
    case get_field(changeset, :cc_recipients) do
      nil ->
        changeset

      cc_recipients when is_list(cc_recipients) ->
        if Enum.all?(cc_recipients, &valid_cc_recipient?/1) do
          changeset
        else
          add_error(changeset, :cc_recipients, "must be a list of maps with name and email keys")
        end

      _ ->
        add_error(changeset, :cc_recipients, "must be a list")
    end
  end

  defp valid_cc_recipient?(%{"name" => name, "email" => email})
       when is_binary(name) and is_binary(email) do
    String.match?(email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/)
  end

  defp valid_cc_recipient?(_), do: false

  def signature_types, do: @signature_types
end
