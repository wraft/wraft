defmodule WraftDoc.Document.ESignature do
  @moduledoc false

  use WraftDoc.Schema

  schema "e_signature" do
    field(:api_url, :string)
    field(:body, :string)
    field(:header, :string)
    field(:file, :string)
    field(:signed_file, :string)
    belongs_to(:instance, WraftDoc.Document.Instance)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    timestamps()
  end

  def changeset(e_signature, attrs \\ %{}) do
    e_signature
    |> cast(attrs, [:api_url, :body, :header, :file, :signed_file])
    |> validate_required([:api_url, :body])
  end
end
