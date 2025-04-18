defmodule WraftDoc.Documents.Signatures do
  @moduledoc """
  Context module for managing digital signatures for documents.
  """

  import Ecto.Query
  require Logger

  alias WraftDoc
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker

  @doc """
  Get a signature by counterparty ID
  """
  @spec get_signature_by_counterparty(CounterParty.t()) :: ESignature.t() | nil
  def get_signature_by_counterparty(%CounterParty{id: counter_party_id}) do
    ESignature
    |> where([s], s.counter_party_id == ^counter_party_id)
    |> preload([:user, :counter_party, content: [:creator]])
    |> Repo.one()
  end

  def get_signature_by_counterparty(_), do: nil

  @doc """
  Create a new signature request for a document
  """
  @spec create_signature(Instance.t(), User.t(), CounterParty.t() | [CounterParty.t()]) ::
          {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def create_signature(
        %Instance{id: document_id} = _instance,
        %User{id: user_id, current_org_id: org_id} = _user,
        %CounterParty{id: counter_party_id} = counterparty
      ) do
    case get_signature_by_counterparty(counterparty) do
      nil ->
        signature_params = %{
          content_id: document_id,
          user_id: user_id,
          organisation_id: org_id,
          counter_party_id: counter_party_id,
          verification_token: WraftDoc.generate_token(32)
        }

        %ESignature{}
        |> ESignature.changeset(signature_params)
        |> Repo.insert()
        |> case do
          {:ok, signature} ->
            Repo.preload(signature, [:counter_party, :user, :content])

          {:error, changeset} ->
            {:error, changeset}
        end

      %ESignature{} = signature ->
        signature
    end
  end

  def create_signature(instance, user, counterparty_list),
    do: Enum.each(counterparty_list, &create_signature(instance, user, &1))

  @doc """
  Get pending signatures for a document
  """
  def get_document_pending_signatures(<<_::288>> = document_id) do
    CounterParty
    |> where([cp], cp.content_id == ^document_id and cp.signature_status == :pending)
    |> preload([:content, :user])
    |> Repo.all()
  end

  @doc """
  Get all signatures for a document
  """
  def get_document_signatures(document_id) do
    ESignature
    |> where([s], s.content_id == ^document_id)
    |> preload([:content, :user, :organisation, :counter_party])
    |> Repo.all()
  end

  @doc """
  Delete a signature by ID
  """
  @spec delete_signature(ESignature.t()) :: {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def delete_signature(%ESignature{} = signature), do: Repo.delete(signature)

  @doc """
  Check if all signatures for a document are complete
  """
  @spec check_document_signature_status(Instance.t()) ::
          {:ok, Instance.t()} | {:error, :not_signed}
  def check_document_signature_status(%Instance{id: document_id}) do
    document_id
    |> get_document_pending_signatures()
    |> Enum.empty?()
    |> case do
      true ->
        # All signatures are complete
        finalize_signed_document(document_id)

      false ->
        # There are still pending signatures
        {:error, :not_signed}
    end
  end

  # Finalize the document after all signatures are complete
  defp finalize_signed_document(instance) do
    # Logic to finalize the document after all signatures
    # This could include:
    # - Marking the document as fully signed
    # - Generating a final signed PDF
    # - Updating the document status
    # - Sending notifications to all parties

    # Future implementation details would go here
    {:ok, instance}
  end

  @doc """
  Update ESignature with signature data
  """
  @spec update_e_signature(ESignature.t(), String.t()) ::
          {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def update_e_signature(%ESignature{} = signature, params) do
    signature
    |> ESignature.signature_changeset(
      Map.merge(params, %{
        "is_valid" => true,
        "signature_date" => DateTime.utc_now()
      })
    )
    |> Repo.update()
  end

  @doc """
  Verify a signature by token
  """
  @spec verify_signature_by_token(Instance.t(), User.t(), String.t()) :: ESignature.t() | nil
  def verify_signature_by_token(
        %Instance{id: document_id},
        %User{id: user_id},
        token
      )
      when is_binary(token) do
    ESignature
    |> where(
      [s],
      s.verification_token == ^token and s.content_id == ^document_id
    )
    |> join(:inner, [s], cp in CounterParty,
      on: s.counter_party_id == cp.id and s.content_id == cp.content_id
    )
    |> where([s, cp], cp.user_id == ^user_id)
    |> preload([s, cp], [:content, :counter_party, :user])
    |> Repo.one()
  end

  @doc """
   Send a signature request email to the counterparty
  """
  @spec signature_request_email(%Instance{}, %CounterParty{}, String.t()) ::
          {:ok, Oban.Job.t()} | {:error, Oban.Job.changeset() | term()}
  def signature_request_email(
        %Instance{instance_id: instance_id, id: document_id},
        %CounterParty{name: name, email: email},
        token
      ) do
    %{
      email: email,
      name: name,
      token: token,
      document_id: document_id,
      instance_id: instance_id
    }
    |> EmailWorker.new(queue: "mailer", tags: ["document_signature_request"])
    |> Oban.insert()
  end

  @doc """
  Send signature request emails to all counterparties for a document
  """
  @spec signature_request_email(%Instance{}, [CounterParty.t()]) :: :ok
  def signature_request_email(instance, counterparties) do
    Enum.each(counterparties, fn %CounterParty{email: email} = counterparty ->
      {:ok, %AuthToken{value: token}} = AuthTokens.create_signer_invite_token(instance, email)
      signature_request_email(instance, counterparty, token)
    end)
  end

  @doc """
  Notify the document owner when a signature is completed
  """
  def notify_document_owner_email(
        %ESignature{
          content: %Instance{creator: owner, instance_id: instance_id},
          counter_party: counterparty
        } =
          _signature
      ) do
    %{
      email: owner.email,
      instance_id: instance_id,
      signer_name: counterparty.name
    }
    |> EmailWorker.new(queue: "mailer", tags: ["notify_document_owner_signature_complete"])
    |> Oban.insert()
  end
end
