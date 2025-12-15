defmodule WraftDoc.ApiKeysTest do
  @moduledoc false
  use WraftDoc.ModelCase
  @moduletag :api_keys

  alias WraftDoc.ApiKeys
  alias WraftDoc.ApiKeys.ApiKey
  alias WraftDoc.Repo
  import WraftDoc.Factory

  describe "list_api_keys/2" do
    test "returns paginated list of API keys for user's organisation" do
      user = insert(:user_with_organisation)

      api_key_1 =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      api_key_2 =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      other_org = insert(:organisation)
      other_user = insert(:user, current_org_id: other_org.id, owned_organisations: [other_org])

      _other_api_key =
        insert(:api_key,
          organisation_id: other_org.id,
          user_id: other_user.id,
          created_by_id: other_user.id
        )

      %{entries: api_keys, total_entries: total} = ApiKeys.list_api_keys(user, %{})

      assert total == 2
      api_key_ids = Enum.map(api_keys, & &1.id)
      assert api_key_1.id in api_key_ids
      assert api_key_2.id in api_key_ids
    end

    test "returns empty list when no API keys exist" do
      user = insert(:user_with_organisation)

      %{entries: api_keys, total_entries: total} = ApiKeys.list_api_keys(user, %{})

      assert api_keys == []
      assert total == 0
    end
  end

  describe "get_api_key/2" do
    test "returns API key for user's organisation" do
      user = insert(:user_with_organisation)

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      result = ApiKeys.get_api_key(user, api_key.id)

      assert result.id == api_key.id
    end

    test "returns nil for API key from different organisation" do
      user = insert(:user_with_organisation)
      other_org = insert(:organisation)
      other_user = insert(:user, current_org_id: other_org.id, owned_organisations: [other_org])

      api_key =
        insert(:api_key,
          organisation_id: other_org.id,
          user_id: other_user.id,
          created_by_id: other_user.id
        )

      result = ApiKeys.get_api_key(user, api_key.id)

      assert result == nil
    end

    test "returns nil for non-existent API key" do
      user = insert(:user_with_organisation)

      result = ApiKeys.get_api_key(user, Ecto.UUID.generate())

      assert result == nil
    end
  end

  describe "get_api_key_by_key/1" do
    test "returns API key when valid key is provided" do
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

      key = api_key.key

      result = ApiKeys.get_api_key_by_key(key)

      assert result != nil
      assert result.id == api_key.id
    end

    test "returns nil for invalid key" do
      result = ApiKeys.get_api_key_by_key("wraft_invalid_key")

      assert result == nil
    end

    test "returns nil for inactive key" do
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

      key = api_key.key

      # Deactivate the key
      api_key
      |> ApiKey.update_changeset(%{is_active: false})
      |> Repo.update!()

      result = ApiKeys.get_api_key_by_key(key)

      assert result != nil
      assert result.is_active == false
    end

    test "returns nil for expired key" do
      organisation = insert(:organisation)
      user = insert(:user)
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          expires_at: future_date
        })
        |> Repo.insert()

      key = api_key.key

      past_date = DateTime.truncate(:DateTime.add(DateTime.utc_now(), -3600, :second), :second)

      api_key
      |> Ecto.Changeset.change(expires_at: past_date)
      |> Repo.update!()

      result = ApiKeys.get_api_key_by_key(key)

      assert result != nil
      assert DateTime.compare(result.expires_at, DateTime.utc_now()) == :lt
    end
  end

  describe "create_api_key/2" do
    test "creates API key with valid attributes" do
      user = insert(:user_with_organisation)

      {:ok, api_key} =
        ApiKeys.create_api_key(user, %{
          "name" => "Test API Key",
          "rate_limit" => 1000
        })

      assert api_key.name == "Test API Key"
      assert api_key.rate_limit == 1000
      assert api_key.organisation_id == user.current_org_id
      assert api_key.user_id == user.id
      assert api_key.created_by_id == user.id
      assert api_key.key != nil
      assert String.starts_with?(api_key.key, "wraft_")
    end

    test "creates API key with custom user_id" do
      creator = insert(:user_with_organisation)
      other_user = insert(:user)

      List.first(
        insert(:user_organisation,
          user: other_user,
          organisation: creator.owned_organisations
        )
      )

      {:ok, api_key} =
        ApiKeys.create_api_key(creator, %{
          "name" => "Test API Key",
          "user_id" => other_user.id
        })

      assert api_key.user_id == other_user.id
      assert api_key.created_by_id == creator.id
    end

    test "returns error with invalid attributes" do
      user = insert(:user_with_organisation)

      {:error, changeset} =
        ApiKeys.create_api_key(user, %{
          "name" => nil
        })

      refute changeset.valid?
    end
  end

  describe "update_api_key/2" do
    test "updates API key with valid attributes" do
      user = insert(:user_with_organisation)

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id,
          name: "Old Name",
          rate_limit: 500
        )

      {:ok, updated} =
        ApiKeys.update_api_key(api_key, %{
          name: "New Name",
          rate_limit: 1000
        })

      assert updated.name == "New Name"
      assert updated.rate_limit == 1000
    end

    test "returns error with invalid attributes" do
      user = insert(:user_with_organisation)

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      {:error, changeset} =
        ApiKeys.update_api_key(api_key, %{
          rate_limit: -10
        })

      refute changeset.valid?
    end
  end

  describe "delete_api_key/1" do
    test "deletes API key" do
      user = insert(:user_with_organisation)

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id
        )

      {:ok, deleted} = ApiKeys.delete_api_key(api_key)

      assert deleted.id == api_key.id
      assert Repo.get(ApiKey, api_key.id) == nil
    end
  end

  describe "toggle_api_key_status/1" do
    test "toggles active status to inactive" do
      user = insert(:user_with_organisation)

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id,
          is_active: true
        )

      {:ok, updated} = ApiKeys.toggle_api_key_status(api_key)

      assert updated.is_active == false
    end

    test "toggles inactive status to active" do
      user = insert(:user_with_organisation)

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id,
          is_active: false
        )

      {:ok, updated} = ApiKeys.toggle_api_key_status(api_key)

      assert updated.is_active == true
    end
  end

  describe "record_usage/1" do
    test "increments usage count and updates last_used_at" do
      user = insert(:user_with_organisation)

      api_key =
        insert(:api_key,
          organisation_id: user.current_org_id,
          user_id: user.id,
          created_by_id: user.id,
          usage_count: 5,
          last_used_at: nil
        )

      {:ok, updated} = ApiKeys.record_usage(api_key)

      assert updated.usage_count == 6
      assert updated.last_used_at != nil
    end
  end

  describe "verify_api_key/2" do
    test "returns user and organisation for valid key" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id
        })
        |> Repo.insert()

      key = api_key.key

      {:ok, result} = ApiKeys.verify_api_key(key)

      assert result.api_key.id == api_key.id
      assert result.user.id == user.id
      assert result.organisation.id == organisation.id
    end

    test "returns error for invalid key" do
      {:error, reason} = ApiKeys.verify_api_key("wraft_invalid_key")

      assert reason == :invalid_api_key
    end

    test "returns error for inactive key" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          is_active: false
        })
        |> Repo.insert()

      key = api_key.key

      {:error, reason} = ApiKeys.verify_api_key(key)

      assert reason == :api_key_inactive
    end

    test "returns error for expired key" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)
      future_date = DateTime.add(DateTime.utc_now(), 3600, :second)

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          expires_at: future_date
        })
        |> Repo.insert()

      key = api_key.key

      past_date = DateTime.truncate(DateTime.add(DateTime.utc_now(), -3600, :second), :second)

      api_key
      |> Ecto.Changeset.change(expires_at: past_date)
      |> Repo.update!()

      {:error, reason} = ApiKeys.verify_api_key(key)

      assert reason == :api_key_expired
    end

    test "returns error when IP not in whitelist" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          ip_whitelist: ["192.168.1.1"]
        })
        |> Repo.insert()

      key = api_key.key

      {:error, reason} = ApiKeys.verify_api_key(key, "192.168.1.2")

      assert reason == :ip_not_whitelisted
    end

    test "succeeds when IP is in whitelist" do
      user = insert(:user_with_organisation)
      organisation = List.first(user.owned_organisations)
      insert(:user_organisation, user: user, organisation: organisation)

      {:ok, api_key} =
        %ApiKey{}
        |> ApiKey.create_changeset(%{
          name: "Test Key",
          organisation_id: organisation.id,
          user_id: user.id,
          ip_whitelist: ["192.168.1.1"]
        })
        |> Repo.insert()

      key = api_key.key

      {:ok, _result} = ApiKeys.verify_api_key(key, "192.168.1.1")
    end
  end
end
