defmodule WraftDoc.ApiKeys.ApiKeyTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :api_keys

  alias WraftDoc.ApiKeys.ApiKey
  alias WraftDoc.Repo
  import WraftDoc.Factory

  @valid_attrs %{
    name: "Test API Key",
    rate_limit: 1000
  }

  @invalid_attrs %{
    name: nil,
    organisation_id: nil,
    user_id: nil
  }

  describe "create_changeset/2" do
    test "changeset with valid attributes generates API key" do
      organisation = insert(:organisation)
      user = insert(:user)

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          rate_limit: 500
        })

      assert changeset.valid?
      assert get_change(changeset, :key_hash) != nil
      assert get_change(changeset, :key_prefix) != nil
      assert get_change(changeset, :key) != nil

      # Check key format
      key = get_change(changeset, :key)
      assert String.starts_with?(key, "wraft_")
    end

    test "changeset with invalid attributes" do
      changeset = ApiKey.create_changeset(%ApiKey{}, @invalid_attrs)
      refute changeset.valid?
    end

    test "validates name length" do
      organisation = insert(:organisation)
      user = insert(:user)

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          name: "ab",
          organisation_id: organisation.id,
          user_id: user.id
        })

      refute changeset.valid?
      assert "should be at least 3 character(s)" in errors_on(changeset, :name)
    end

    test "validates rate_limit is positive" do
      organisation = insert(:organisation)
      user = insert(:user)

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          rate_limit: -10
        })

      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset, :rate_limit)
    end

    test "validates expires_at is in the future" do
      organisation = insert(:organisation)
      user = insert(:user)
      past_date = DateTime.add(DateTime.utc_now(), -3600, :second)

      changeset =
        ApiKey.create_changeset(%ApiKey{}, %{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          expires_at: past_date
        })

      refute changeset.valid?
      assert "must be in the future" in errors_on(changeset, :expires_at)
    end

    test "foreign key constraint on user_id" do
      organisation = insert(:organisation)

      params = %{
        name: "Test Key",
        organisation_id: organisation.id,
        user_id: Ecto.UUID.generate()
      }

      {:error, changeset} = %ApiKey{} |> ApiKey.create_changeset(params) |> Repo.insert()

      assert "does not exist" in errors_on(changeset, :user_id)
    end

    test "foreign key constraint on organisation_id" do
      user = insert(:user)

      params = %{
        name: "Test Key",
        organisation_id: Ecto.UUID.generate(),
        user_id: user.id
      }

      {:error, changeset} = %ApiKey{} |> ApiKey.create_changeset(params) |> Repo.insert()

      assert "does not exist" in errors_on(changeset, :organisation_id)
    end

    test "unique constraint on name per organisation" do
      organisation = insert(:organisation)
      user = insert(:user)

      params = %{
        name: "Unique Key",
        organisation_id: organisation.id,
        user_id: user.id
      }

      {:ok, _api_key} = %ApiKey{} |> ApiKey.create_changeset(params) |> Repo.insert()

      {:error, changeset} = %ApiKey{} |> ApiKey.create_changeset(params) |> Repo.insert()

      assert "has already been taken" in errors_on(changeset, :name)
    end
  end

  describe "update_changeset/2" do
    test "allows updating name and settings" do
      api_key = insert(:api_key)

      changeset =
        ApiKey.update_changeset(api_key, %{
          name: "Updated Name",
          rate_limit: 2000,
          is_active: false
        })

      assert changeset.valid?
      assert get_change(changeset, :name) == "Updated Name"
      assert get_change(changeset, :rate_limit) == 2000
      assert get_change(changeset, :is_active) == false
    end

    test "does not allow changing the key itself" do
      api_key = insert(:api_key)

      changeset =
        ApiKey.update_changeset(api_key, %{
          key_hash: "new_hash"
        })

      # key_hash should not be in the changeset changes
      assert get_change(changeset, :key_hash) == nil
    end
  end

  describe "verify_key?/2" do
    test "returns true for matching key" do
      organisation = insert(:organisation)
      user = insert(:user)

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id
        })
        |> Repo.insert()

      # Get the unhashed key from the virtual field
      key = api_key.key

      # Reload the api_key from DB
      api_key_from_db = Repo.get!(ApiKey, api_key.id)

      assert ApiKey.verify_key?(api_key_from_db, key)
    end

    test "returns false for non-matching key" do
      api_key = insert(:api_key)
      assert ApiKey.verify_key?(api_key, "wrong_key") == false
    end
  end

  describe "valid?/1" do
    test "returns false for inactive key" do
      api_key = insert(:api_key, is_active: false)
      refute ApiKey.valid?(api_key)
    end

    test "returns true for active key without expiration" do
      api_key = insert(:api_key, is_active: true, expires_at: nil)
      assert ApiKey.valid?(api_key)
    end

    test "returns true for active key with future expiration" do
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second)
      api_key = insert(:api_key, is_active: true, expires_at: future_date)
      assert ApiKey.valid?(api_key)
    end

    test "returns false for expired key" do
      past_date = DateTime.add(DateTime.utc_now(), -3600, :second)
      api_key = insert(:api_key, is_active: true, expires_at: past_date)
      refute ApiKey.valid?(api_key)
    end
  end

  describe "ip_allowed?/2" do
    test "returns true when ip_whitelist is empty" do
      api_key = insert(:api_key, ip_whitelist: [])
      assert ApiKey.ip_allowed?(api_key, "192.168.1.1")
    end

    test "returns true when IP is in the whitelist" do
      api_key = insert(:api_key, ip_whitelist: ["192.168.1.1", "10.0.0.1"])
      assert ApiKey.ip_allowed?(api_key, "192.168.1.1")
    end

    test "returns false when IP is not in the whitelist" do
      api_key = insert(:api_key, ip_whitelist: ["192.168.1.1"])
      refute ApiKey.ip_allowed?(api_key, "192.168.1.2")
    end
  end
end
