defmodule WraftDoc.Documents.Signatures do
  @moduledoc """
  Context module for managing digital signatures for documents.
  """

  import Ecto.Query
  require Logger

  alias WraftDoc.Account.User
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Mailer
  alias WraftDocWeb.Mailer.SignatureEmail

  @doc """
  Get a signature by ID
  """
  def get_signature(id) do
    ESignature
    |> Repo.get(id)
    |> Repo.preload([:content, :user, :organisation, :counter_party])
  end

  @doc """
  Create a new signature request for a document
  """
  @spec create_signature(Instance.t(), User.t(), CounterParty.t(), map()) ::
          {:ok, ESignature.t()} | {:error, Ecto.Changeset.t()}
  def create_signature(
        %Instance{id: instance_id} = _instance,
        %User{id: user_id, current_org_id: org_id} = _user,
        %CounterParty{id: counter_party_id} = _counterparty,
        %{"signature_type" => signature_type}
      ) do
    signature_params = %{
      signature_type: signature_type,
      content_id: instance_id,
      user_id: user_id,
      organisation_id: org_id,
      counter_party_id: counter_party_id
    }

    %ESignature{}
    |> ESignature.changeset(signature_params)
    |> Repo.insert()
    |> case do
      {:ok, signature} ->
        {:ok, Repo.preload(signature, [:counter_party, :content, :user])}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Get pending signatures for a document
  """
  def get_document_pending_signatures(document_id) do
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
  Process a signature for a document
  """
  def process_signature(
        %CounterParty{id: counter_party_id} = counterparty,
        %{"signature_data" => signature_data, "ip_address" => ip_address} = params
      ) do
    now = DateTime.utc_now()

    # Update the counterparty status
    counterparty_result =
      counterparty
      |> CounterParty.sign_changeset(%{
        signature_status: :signed,
        signature_date: now,
        signature_ip: ip_address
      })
      |> Repo.update()

    # Get the associated signature request
    signature =
      ESignature
      |> where([s], s.counter_party_id == ^counter_party_id)
      |> limit(1)
      |> Repo.one()
      |> Repo.preload([:user, :counter_party, content: [:creator]])

    if signature do
      # Update the signature with the provided data
      signature_result =
        signature
        |> ESignature.signature_changeset(%{
          signature_data: signature_data,
          signature_position: Map.get(params, "signature_position", %{}),
          ip_address: ip_address,
          signature_date: now,
          is_valid: true
        })
        |> Repo.update()

      case {counterparty_result, signature_result} do
        {{:ok, updated_counterparty}, {:ok, updated_signature}} ->
          # Check if all signatures are complete and handle document finalization
          check_document_signature_status(updated_signature.content_id)

          # Notify document owner about the signature
          notify_document_owner(updated_signature)

          {:ok, %{counterparty: updated_counterparty, signature: updated_signature}}

        {{:error, counterparty_changeset}, _} ->
          {:error, counterparty_changeset}

        {_, {:error, signature_changeset}} ->
          {:error, signature_changeset}
      end
    else
      {:error, :signature_not_found}
    end
  end

  # Check if all signatures for a document are complete
  defp check_document_signature_status(document_id) do
    pending_signatures = get_document_pending_signatures(document_id)

    if Enum.empty?(pending_signatures) do
      # All signatures are complete, update document status
      finalize_signed_document(document_id)
    end
  end

  # Finalize the document after all signatures are complete
  defp finalize_signed_document(document_id) do
    # Logic to finalize the document after all signatures
    # This could include:
    # - Marking the document as fully signed
    # - Generating a final signed PDF
    # - Updating the document status
    # - Sending notifications to all parties

    # Get the document
    document =
      Instance
      |> Repo.get(document_id)
      |> Repo.preload([:creator, :content_type])

    # Future implementation details would go here
    {:ok, document}
  end

  @doc """
  Verify a signature by token
  """
  def verify_signature_by_token(token) when is_binary(token) do
    ESignature
    |> where([s], s.verification_token == ^token)
    |> limit(1)
    |> Repo.one()
    |> Repo.preload([:content, :counter_party, :user])
    |> case do
      %ESignature{} = signature -> {:ok, signature}
      nil -> {:error, :invalid_token}
    end
  end

  @doc """
   Send a signature request email to the counterparty
  """
  @spec signature_request_email(%Instance{}, %CounterParty{}, String.t()) ::
          {:ok, Oban.Job.t()} | {:error, Oban.Job.changeset() | term()}
  def signature_request_email(
        %Instance{instance_id: instance_id},
        %CounterParty{name: name, email: email},
        token
      ) do
    %{
      email: email,
      name: name,
      token: token,
      instance_id: instance_id
    }
    |> EmailWorker.new(queue: "mailer", tags: ["document_signature_request"])
    |> Oban.insert()
  end

  # Notify document owner about signature
  defp notify_document_owner(
         %ESignature{content: %Instance{creator: owner} = instance, counter_party: counterparty} =
           _signature
       ) do
    # Code to notify document owner about the signature
    Mailer.deliver(
      SignatureEmail.signature_completed_email(
        owner.email,
        instance,
        counterparty.name
      )
    )
  end
end
