defmodule WraftDocWeb.Api.V1.ApiKeyView do
  use WraftDocWeb, :view

  alias WraftDoc.ApiKeys.ApiKey

  def render("index.json", %{
        api_keys: api_keys,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      api_keys: render_many(api_keys, __MODULE__, "api_key_list.json", as: :api_key),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("api_key.json", %{api_key: api_key}) do
    maybe_add_key(
      %{
        id: api_key.id,
        name: api_key.name,
        key_prefix: api_key.key_prefix,
        expires_at: api_key.expires_at,
        is_active: api_key.is_active,
        rate_limit: api_key.rate_limit,
        ip_whitelist: api_key.ip_whitelist,
        last_used_at: api_key.last_used_at,
        usage_count: api_key.usage_count,
        metadata: api_key.metadata,
        inserted_at: api_key.inserted_at,
        updated_at: api_key.updated_at,
        user: render_user(api_key),
        created_by: render_created_by(api_key)
      },
      api_key
    )
  end

  def render("api_key_list.json", %{api_key: api_key}) do
    %{
      id: api_key.id,
      name: api_key.name,
      key_prefix: api_key.key_prefix,
      is_active: api_key.is_active,
      rate_limit: api_key.rate_limit,
      last_used_at: api_key.last_used_at,
      usage_count: api_key.usage_count,
      expires_at: api_key.expires_at,
      inserted_at: api_key.inserted_at,
      updated_at: api_key.updated_at
    }
  end

  # Private functions
  defp maybe_add_key(map, %ApiKey{key: key}) when is_binary(key) do
    # Only include the key if it's available (i.e., during creation)
    Map.put(map, :key, key)
  end

  defp maybe_add_key(map, _api_key), do: map

  defp render_user(%ApiKey{user: %Ecto.Association.NotLoaded{}}), do: nil

  defp render_user(%ApiKey{user: nil}), do: nil

  defp render_user(%ApiKey{user: user}) do
    %{
      id: user.id,
      name: user.name,
      email: user.email
    }
  end

  defp render_created_by(%ApiKey{created_by: %Ecto.Association.NotLoaded{}}), do: nil

  defp render_created_by(%ApiKey{created_by: nil}), do: nil

  defp render_created_by(%ApiKey{created_by: user}) do
    %{
      id: user.id,
      name: user.name,
      email: user.email
    }
  end
end
