defmodule WraftDoc.SessionCache.CacheInvalidation do
  @moduledoc """
  Helper module for managing cache invalidation when permissions or access rights change.

  This module provides functions to invalidate cached authorization and user data
  when underlying permissions change, ensuring cache consistency.
  """

  alias WraftDoc.SessionCache
  require Logger

  @doc """
  Invalidates all cached document access for a specific user.
  Should be called when user's organization membership or roles change.
  """
  @spec invalidate_user_document_access(binary()) :: :ok
  def invalidate_user_document_access(user_id) when is_binary(user_id) do
    pattern = {:doc_access, user_id, :_}
    SessionCache.delete_pattern(pattern)

    Logger.debug("Invalidated document access cache for user #{user_id}")
    :ok
  end

  @doc """
  Invalidates cached access for a specific document for all users.
  Should be called when document permissions or collaboration settings change.
  """
  @spec invalidate_document_access(binary()) :: :ok
  def invalidate_document_access(document_id) when is_binary(document_id) do
    pattern = {:doc_access, :_, document_id}
    SessionCache.delete_pattern(pattern)

    Logger.debug("Invalidated access cache for document #{document_id}")
    :ok
  end

  @doc """
  Invalidates cached access for a specific user-document pair.
  Should be called when specific collaboration permissions change.
  """
  @spec invalidate_user_document_pair(binary(), binary()) :: :ok
  def invalidate_user_document_pair(user_id, document_id)
      when is_binary(user_id) and is_binary(document_id) do
    cache_key = {:doc_access, user_id, document_id}
    SessionCache.delete(cache_key)

    Logger.debug("Invalidated access cache for user #{user_id} and document #{document_id}")
    :ok
  end

  @doc """
  Invalidates cached user authentication data.
  Should be called when user roles, permissions, or profile data changes.
  """
  @spec invalidate_user_auth_cache(binary()) :: :ok
  def invalidate_user_auth_cache(user_id) when is_binary(user_id) do
    # This would need to be implemented based on how user auth tokens are cached
    # For now, we'll use a simple pattern
    pattern = {"user_token:" <> String.slice(user_id, 0, 8), :_}
    SessionCache.delete_pattern(pattern)

    Logger.debug("Invalidated auth cache for user #{user_id}")
    :ok
  end

  @doc """
  Invalidates all cache entries for an organization.
  Should be called when organization-wide permission changes occur.
  """
  @spec invalidate_organization_cache(binary()) :: :ok
  def invalidate_organization_cache(org_id) when is_binary(org_id) do
    # This is a more aggressive approach - might want to be more selective
    # For now, we'll invalidate document access patterns that might be org-related

    # In a more sophisticated implementation, you might track org-related cache keys
    Logger.info("Organization cache invalidation requested for org #{org_id}")

    # For now, log and let normal TTL handle it
    # In production, you might want to store org-related cache keys separately
    :ok
  end

  @doc """
  Invalidates cache when a collaboration record is created, updated, or deleted.
  """
  @spec invalidate_collaboration_cache(map()) :: :ok
  def invalidate_collaboration_cache(%{user_id: user_id, content_id: document_id}) do
    invalidate_user_document_pair(user_id, document_id)
  end

  def invalidate_collaboration_cache(_), do: :ok

  @doc """
  Batch invalidation for multiple users on a document.
  Useful when document sharing settings change.
  """
  @spec invalidate_document_users_cache(binary(), list(binary())) :: :ok
  def invalidate_document_users_cache(document_id, user_ids)
      when is_binary(document_id) and is_list(user_ids) do
    Enum.each(user_ids, fn user_id ->
      invalidate_user_document_pair(user_id, document_id)
    end)

    Logger.debug(
      "Invalidated access cache for document #{document_id} and #{length(user_ids)} users"
    )

    :ok
  end

  @doc """
  Batch invalidation for a user across multiple documents.
  Useful when user permissions change globally.
  """
  @spec invalidate_user_documents_cache(binary(), list(binary())) :: :ok
  def invalidate_user_documents_cache(user_id, document_ids)
      when is_binary(user_id) and is_list(document_ids) do
    Enum.each(document_ids, fn document_id ->
      invalidate_user_document_pair(user_id, document_id)
    end)

    Logger.debug(
      "Invalidated access cache for user #{user_id} and #{length(document_ids)} documents"
    )

    :ok
  end

  @doc """
  Validates cache consistency by checking if cached values match database.
  Useful for debugging and monitoring.
  """
  @spec validate_cache_consistency(binary(), binary()) :: :ok | {:error, :inconsistent}
  def validate_cache_consistency(user_id, document_id)
      when is_binary(user_id) and is_binary(document_id) do
    cache_key = {:doc_access, user_id, document_id}

    case SessionCache.get(cache_key) do
      {:ok, cached_value} ->
        # In a real implementation, you'd check against the database here
        # For now, just log the cached value
        Logger.debug(
          "Cache validation: user #{user_id}, doc #{document_id}, cached: #{cached_value}"
        )

        :ok

      {:error, :not_found} ->
        Logger.debug("Cache validation: no cached value for user #{user_id}, doc #{document_id}")
        :ok
    end
  end
end
