defmodule WraftDoc.ApiKeys.ApiKey do
  @moduledoc """
  The API Key schema for organization-level API authentication.
  API keys provide an alternative to JWT tokens for third-party integrations.
  """
  use WraftDoc.Schema

  @derive {Jason.Encoder,
           only: [
             :id,
             :name,
             :key_prefix,
             :expires_at,
             :is_active,
             :rate_limit,
             :ip_whitelist,
             :last_used_at,
             :usage_count,
             :metadata,
             :inserted_at,
             :updated_at
           ]}

  schema "api_keys" do
    field(:name, :string)
    field(:key_hash, :string)
    field(:key_prefix, :string)

    # Security settings
    field(:expires_at, :utc_datetime)
    field(:is_active, :boolean, default: true)
    field(:rate_limit, :integer, default: 1000)
    field(:ip_whitelist, {:array, :string}, default: [])

    # Usage tracking
    field(:last_used_at, :utc_datetime)
    field(:usage_count, :integer, default: 0)

    # Additional metadata
    field(:metadata, :map, default: %{})

    # Virtual field to store the unhashed key (only available during creation)
    field(:key, :string, virtual: true)

    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:created_by, WraftDoc.Account.User)

    timestamps()
  end

  @doc """
  Changeset for creating a new API key.
  Generates a random key and hashes it.
  """
  def create_changeset(api_key, attrs \\ %{}) do
    api_key
    |> cast(attrs, [
      :name,
      :organisation_id,
      :user_id,
      :created_by_id,
      :expires_at,
      :is_active,
      :rate_limit,
      :ip_whitelist,
      :metadata
    ])
    |> validate_required([:name, :organisation_id, :user_id])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_number(:rate_limit, greater_than: 0)
    |> validate_expiration_date()
    |> generate_api_key()
    |> unique_constraint([:name, :organisation_id])
    |> unique_constraint(:key_hash)
    |> foreign_key_constraint(:organisation_id)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:created_by_id)
  end

  @doc """
  Changeset for updating an existing API key.
  Does not allow changing the key itself.
  """
  def update_changeset(api_key, attrs \\ %{}) do
    api_key
    |> cast(attrs, [
      :name,
      :expires_at,
      :is_active,
      :rate_limit,
      :ip_whitelist,
      :metadata
    ])
    |> validate_length(:name, min: 3, max: 100)
    |> validate_number(:rate_limit, greater_than: 0)
    |> validate_expiration_date()
    |> unique_constraint([:name, :organisation_id])
  end

  @doc """
  Changeset for updating usage statistics.
  """
  def usage_changeset(api_key, attrs \\ %{}),
    do: cast(api_key, attrs, [:last_used_at, :usage_count])

  # Private functions

  defp validate_expiration_date(changeset) do
    case get_change(changeset, :expires_at) do
      nil ->
        changeset

      expires_at ->
        if DateTime.compare(expires_at, DateTime.utc_now()) == :gt do
          changeset
        else
          add_error(changeset, :expires_at, "must be in the future")
        end
    end
  end

  defp generate_api_key(changeset) do
    if changeset.valid? do
      # Generate a cryptographically secure random key
      # Format: wraft_<prefix>_<random_part>
      prefix = generate_prefix()
      random_part = generate_random_string(32)
      full_key = "wraft_#{prefix}_#{random_part}"

      # Hash the key for storage
      key_hash = Bcrypt.hash_pwd_salt(full_key)

      changeset
      |> put_change(:key, full_key)
      |> put_change(:key_hash, key_hash)
      |> put_change(:key_prefix, prefix)
    else
      changeset
    end
  end

  defp generate_prefix,
    # Generate a 8-character prefix for easy identification
    do: 4 |> :crypto.strong_rand_bytes() |> Base.encode16(case: :lower)

  defp generate_random_string(length) do
    length
    |> :crypto.strong_rand_bytes()
    |> Base.url_encode64(padding: false)
    |> binary_part(0, length)
  end

  @doc """
  Verify if a given key matches the hashed key.
  """
  def verify_key?(api_key, key) do
    Bcrypt.verify_pass(key, api_key.key_hash)
  end

  @doc """
  Check if an API key is valid and not expired.
  """
  def valid?(%__MODULE__{is_active: false}), do: false

  def valid?(%__MODULE__{expires_at: nil}), do: true

  def valid?(%__MODULE__{expires_at: expires_at}) do
    DateTime.compare(DateTime.utc_now(), expires_at) == :lt
  end

  @doc """
  Check if an IP address is allowed for this API key.
  If ip_whitelist is empty, all IPs are allowed.
  """
  def ip_allowed?(%__MODULE__{ip_whitelist: []}, _ip), do: true

  def ip_allowed?(%__MODULE__{ip_whitelist: whitelist}, ip) do
    ip in whitelist
  end
end
