defmodule WraftDoc.Account.Country do
  @moduledoc """
  This is the Country module
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "country" do
    field(:country_name, :string)
    field(:country_code, :string)
    field(:calling_code, :string)
    has_many(:basic_profiles, WraftDoc.Account.Profile)
  end

  def changeset(country, attrs \\ %{}) do
    country
    |> cast(attrs, [:country_name, :country_code, :calling_code])
    |> validate_required([:country_name, :country_code, :calling_code])
  end
end
