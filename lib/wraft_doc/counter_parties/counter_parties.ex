defmodule WraftDoc.CounterParties do
  @moduledoc """
  Module that handles the repo connections of the counter parties context.
  """

  import Ecto.Query

  alias Ecto.Multi
  alias WraftDoc.Account.User
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.ESignature
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Documents.Signatures
  alias WraftDoc.Repo

  @doc """
  Get counterparty for a contract document
  """
  @spec get_counterparty(String.t(), String.t()) :: CounterParty.t() | nil
  def get_counterparty(document_id, <<_::288>> = counterparty_id) do
    Repo.get_by(CounterParty, content_id: document_id, counterparty_id: counterparty_id)
  end

  def get_counterparty(document_id, email) when is_binary(email),
    do: Repo.get_by(CounterParty, content_id: document_id, email: email)

  @doc """
  Get or create a counterparty for a document
  """
  @spec get_or_create_counter_party(Instance.t(), map(), User.t()) ::
          CounterParty.t() | {:error, Ecto.Changeset.t()}
  def get_or_create_counter_party(
        %Instance{id: document_id} = instance,
        %{"name" => _name, "email" => email} = params,
        %User{} = signer
      ) do
    document_id
    |> get_counterparty(email)
    |> case do
      nil ->
        add_counterparty(instance, params, signer)

      %CounterParty{} = counter_party ->
        counter_party
    end
  end

  def get_or_create_counter_party(_, _, _), do: {:error, :invalid_data}

  @doc """
    Accept counterparty access to document
  """
  @spec approve_document_access(CounterParty.t()) ::
          {:ok, CounterParty.t()} | {:error, Ecto.Changeset.t()}
  def approve_document_access(%CounterParty{signature_status: :pending} = counterparty) do
    counterparty
    |> CounterParty.update_status_changeset(%{signature_status: :accepted})
    |> Repo.update()
    |> case do
      {:ok, updated_counterparty} ->
        Repo.preload(updated_counterparty, [:content, :user, :e_signature])

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def approve_document_access(%CounterParty{} = counterparty),
    do: Repo.preload(counterparty, [:content, :user, :e_signature])

  @doc """
   Add counterparty to content
  """
  @spec add_counterparty(Instance.t(), map(), User.t()) ::
          CounterParty.t() | {:error, Ecto.Changeset.t()}
  def add_counterparty(
        %Instance{id: document_id},
        %{"email" => email, "name" => name},
        %User{id: signer_id} = _signer
      ) do
    %CounterParty{}
    |> CounterParty.changeset(%{
      name: name,
      email: email,
      content_id: document_id,
      user_id: signer_id
    })
    |> Repo.insert()
    |> case do
      {:ok, counter_party} ->
        Repo.preload(counter_party, [:user, :content])

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def add_counterparty(_, _), do: {:error, :invalid_data}

  @doc """
    Remove counterparty from content
  """
  @spec remove_counterparty(CounterParty.t()) ::
          {:ok, CounterParty.t()} | {:error, Ecto.Changeset.t()}
  def remove_counterparty(%CounterParty{} = counterparty), do: Repo.delete(counterparty)

  @doc """
  Get all counterparties for a document
  """
  @spec get_document_counterparties(String.t()) :: [CounterParty.t()]
  def get_document_counterparties(document_id) when is_binary(document_id) do
    CounterParty
    |> where([cp], cp.content_id == ^document_id)
    |> preload([:content, :user])
    |> Repo.all()
  end

  @doc """
    Sign document for a counterparty
  """
  @spec sign_document(CounterParty.t(), ESignature.t(), map()) ::
          {:ok, CounterParty.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def sign_document(
        %CounterParty{signature_status: :accepted} = counterparty,
        %ESignature{} = signature,
        params
      ) do
    Multi.new()
    |> Multi.run(:sign_document, fn _repo, _changes ->
      counter_party_sign(counterparty, params)
    end)
    |> Multi.run(:update_signature, fn _repo, _changes ->
      Signatures.update_e_signature(signature, params)
    end)
    |> Repo.transaction()
    |> case do
      {:ok, %{update_signature: updated_signature}} ->
        %{updated_signature | counter_party: Repo.reload(updated_signature.counter_party)}

      {:error, _, changeset, _} ->
        {:error, changeset}
    end
  end

  def sign_document(%CounterParty{signature_status: :pending} = _counterparty, _, _),
    do: {:error, "Signatory has not accepted the document"}

  def sign_document(%CounterParty{signature_status: :signed} = _counterparty, _, _),
    do: {:error, "Document already signed"}

  @doc """
  Update counterparty status to signed
  """
  @spec counter_party_sign(CounterParty.t(), map()) ::
          {:ok, CounterParty.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def counter_party_sign(counter_party, %{"ip_address" => ip_address}) do
    counter_party
    |> CounterParty.sign_changeset(%{
      signature_status: :signed,
      signature_date: DateTime.utc_now(),
      signature_ip: ip_address
    })
    |> Repo.update()
  end

  def counter_party_sign(_, _), do: {:error, :invalid_data}

  def sign_document(%CounterParty{signature_status: :pending}, _),
    do: {:error, "Signatory has not accepted the document"}

  def sign_document(%CounterParty{signature_status: :signed}, _),
    do: {:error, "Document already signed"}
end
