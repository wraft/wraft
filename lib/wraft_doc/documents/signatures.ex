defmodule WraftDoc.Documents.Signatures do
  @moduledoc """
  Context module for managing digital signatures for documents.
  """

  import Ecto.Query
  require Logger

  alias WraftDoc.Account.User
  alias WraftDoc.CounterParties
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo
  alias WraftDoc.Utils.TokenGenerator
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
  def create_signature_request(
        %Instance{id: _instance_id} = instance,
        %User{id: _user_id} = user,
        %{"counterparty" => counterparty_params} = params
      ) do
    # First create or get the counterparty
    with {:ok, %CounterParty{id: _counter_party_id} = counterparty} <-
           ensure_counterparty(instance, counterparty_params),
         {:ok, signature} <- create_signature(instance, user, counterparty, params) do
      # Send signature request email
      send_signature_request_email(signature)

      {:ok, signature}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  # Ensure a counterparty exists for the document
  defp ensure_counterparty(
         %Instance{id: instance_id} = instance,
         %{"email" => email, "name" => _name} = params
       ) do
    case CounterParties.get_counterparty_by_email(instance_id, email) do
      %CounterParty{} = existing_counterparty ->
        {:ok, existing_counterparty}

      nil ->
        CounterParties.add_counterparty(instance, params)
    end
  end

  # Create a signature record
  defp create_signature(
         %Instance{id: instance_id} = _instance,
         %User{id: user_id, current_org_id: org_id} = _user,
         %CounterParty{id: counter_party_id} = _counterparty,
         params
       ) do
    # Generate verification token
    verification_token = TokenGenerator.generate(32)

    signature_params = %{
      api_url: Map.get(params, "api_url", "/api/v1/signatures"),
      body: Jason.encode!(%{document_id: instance_id, counterparty_id: counter_party_id}),
      header: Jason.encode!(%{content_type: "application/json"}),
      signature_type: Map.get(params, "signature_type", "digital"),
      verification_token: verification_token,
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
    |> preload([:content, :guest_user])
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

  # Send signature request email
  defp send_signature_request_email(
         %ESignature{counter_party: counterparty, content: instance, verification_token: token} =
           _signature
       ) do
    # Code to send email with signature link
    # Create a URL with the verification token
    signature_url = "#{Application.get_env(:wraft_doc, :base_url)}/sign/#{token}"
    # Send the email
    Mailer.deliver(
      SignatureEmail.signature_request_email(
        counterparty.email,
        instance,
        signature_url,
        counterparty.name
      )
    )
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
