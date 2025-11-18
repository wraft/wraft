defmodule WraftDoc.Workflows.WorkflowCredentials do
  @moduledoc """
  Context for managing workflow credentials.

  Handles creation, retrieval, and decryption of credentials for workflow adaptors.
  Credentials are encrypted at rest and organization-scoped.
  """

  import Ecto.Query
  alias WraftDoc.Account.User
  alias WraftDoc.Repo
  alias WraftDoc.Workflows.WorkflowCredential

  @doc """
  Create a new credential scoped to the user's organization.

  ## Examples

      iex> create_credential(user, %{
      ...>   "name" => "API Key",
      ...>   "adaptor_type" => "http",
      ...>   "credentials" => %{"api_key" => "secret"}
      ...> })
      {:ok, %WorkflowCredential{}}
  """
  @spec create_credential(User.t(), map()) ::
          {:ok, WorkflowCredential.t()} | {:error, Ecto.Changeset.t()}
  def create_credential(%User{current_org_id: org_id} = user, attrs) when is_map(attrs) do
    credentials = Map.get(attrs, "credentials") || Map.get(attrs, :credentials)

    if credentials do
      # Encrypt credentials using EncryptedBinaryType
      # The changeset will handle encryption via the EncryptedBinaryType
      encrypted_credentials =
        case credentials do
          credentials when is_map(credentials) ->
            then(Jason.encode!(credentials), &{:ok, &1})

          credentials when is_binary(credentials) ->
            {:ok, credentials}

          _ ->
            {:error, "credentials must be a map or string"}
        end

      case encrypted_credentials do
        {:ok, creds_binary} ->
          attrs =
            attrs
            |> Map.put("organisation_id", org_id)
            |> Map.put("creator_id", user.id)
            |> Map.put("credentials_encrypted", creds_binary)

          %WorkflowCredential{}
          |> WorkflowCredential.changeset(attrs)
          |> Repo.insert()

        error ->
          error
      end
    else
      {:error, :credentials_required}
    end
  end

  @doc """
  Get a credential by ID within the user's organization.

  Returns the credential with decrypted credentials_encrypted field.
  """
  @spec get_credential(User.t(), Ecto.UUID.t()) :: WorkflowCredential.t() | nil
  def get_credential(%User{current_org_id: org_id}, credential_id) do
    WorkflowCredential
    |> where([c], c.id == ^credential_id and c.organisation_id == ^org_id)
    |> Repo.one()
  end

  @doc """
  List all credentials for the user's organization.
  """
  @spec list_credentials(User.t(), keyword()) :: [WorkflowCredential.t()]
  def list_credentials(%User{current_org_id: org_id}, opts \\ []) do
    query =
      WorkflowCredential
      |> where([c], c.organisation_id == ^org_id)
      |> order_by([c], desc: c.inserted_at)

    filtered_query =
      case Keyword.get(opts, :adaptor_type) do
        nil -> query
        adaptor_type -> where(query, [c], c.adaptor_type == ^adaptor_type)
      end

    Repo.all(filtered_query)
  end

  @doc """
  Update a credential.
  """
  @spec update_credential(User.t(), WorkflowCredential.t(), map()) ::
          {:ok, WorkflowCredential.t()} | {:error, Ecto.Changeset.t()}
  def update_credential(
        %User{current_org_id: org_id},
        %WorkflowCredential{organisation_id: org_id} = credential,
        attrs
      ) do
    # Handle credentials encryption if provided
    attrs =
      if Map.has_key?(attrs, "credentials") || Map.has_key?(attrs, :credentials) do
        credentials = Map.get(attrs, "credentials") || Map.get(attrs, :credentials)

        case credentials do
          credentials when is_map(credentials) ->
            creds_binary = Jason.encode!(credentials)

            attrs
            |> Map.put("credentials_encrypted", creds_binary)
            |> Map.delete("credentials")

          credentials when is_binary(credentials) ->
            attrs
            |> Map.put("credentials_encrypted", credentials)
            |> Map.delete("credentials")

          _ ->
            attrs
        end
      else
        attrs
      end

    credential
    |> WorkflowCredential.changeset(attrs)
    |> Repo.update()
  end

  def update_credential(_, _, _), do: {:error, :forbidden}

  @doc """
  Delete a credential.
  """
  @spec delete_credential(User.t(), WorkflowCredential.t()) ::
          {:ok, WorkflowCredential.t()} | {:error, Ecto.Changeset.t()}
  def delete_credential(
        %User{current_org_id: org_id},
        %WorkflowCredential{organisation_id: org_id} = credential
      ) do
    Repo.delete(credential)
  end

  def delete_credential(_, _), do: {:error, :forbidden}

  @doc """
  Decrypt and retrieve credentials from a WorkflowCredential.

  Returns the decrypted credentials as a map (JSON) or binary string.

  Note: EncryptedBinaryType automatically decrypts when loaded from DB,
  so credentials_encrypted field is already decrypted at this point.
  """
  @spec decrypt_credentials(WorkflowCredential.t()) :: map() | binary()
  def decrypt_credentials(%WorkflowCredential{credentials_encrypted: encrypted}) do
    # EncryptedBinaryType automatically decrypts when loaded from DB
    # So encrypted field is already decrypted
    case encrypted do
      nil ->
        %{}

      decrypted when is_binary(decrypted) ->
        # Try to parse as JSON, fallback to plain string
        case Jason.decode(decrypted) do
          {:ok, json} -> json
          :error -> decrypted
        end

      other when is_map(other) ->
        other

      other ->
        other
    end
  end

  @doc """
  Get credentials for a job, loading and decrypting them.

  Returns nil if no credentials are associated with the job.
  """
  @spec get_job_credentials(WraftDoc.Workflows.WorkflowJob.t()) :: map() | nil
  def get_job_credentials(%WraftDoc.Workflows.WorkflowJob{credentials_id: nil}), do: nil

  def get_job_credentials(%WraftDoc.Workflows.WorkflowJob{credentials_id: credential_id}) do
    case Repo.get(WorkflowCredential, credential_id) do
      nil -> nil
      credential -> decrypt_credentials(credential)
    end
  end
end
