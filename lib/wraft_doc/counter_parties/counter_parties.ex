defmodule WraftDoc.CounterParties do
  @moduledoc """
  Module that handles the repo connections of the counter parties context.
  """

  import Ecto.Query

  alias WraftDoc.Account.User
  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo

  @doc """
  Get counterparty for a contract document
  """
  @spec get_counterparty(String.t(), String.t()) :: CounterParty.t() | nil
  def get_counterparty(<<_::288>> = document_id, <<_::288>> = counterparty_id) do
    Repo.get_by(CounterParty, content_id: document_id, id: counterparty_id)
  end

  def get_counterparty(document_id, email) when is_binary(email),
    do: Repo.get_by(CounterParty, content_id: document_id, email: email)

  @doc """
   Get counterparty with signatures preloaded
  """
  @spec get_counterparty_with_signatures(User.t(), Ecto.UUID.t()) :: CounterParty.t() | nil
  def get_counterparty_with_signatures(%User{id: user_id}, <<_::288>> = document_id) do
    CounterParty
    |> where([cp], cp.content_id == ^document_id and cp.user_id == ^user_id)
    |> preload([:e_signature])
    |> Repo.one()
  end

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
        %{
          "email" => email,
          "name" => name,
          "color_rgb" => color_rgb
        },
        %User{id: user_id} = _user
      ) do
    %CounterParty{}
    |> CounterParty.changeset(%{
      name: name,
      email: email,
      content_id: document_id,
      user_id: user_id,
      color_rgb: color_rgb
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
  @spec get_document_counterparties(Ecto.UUID.t()) :: [CounterParty.t()] | {:error, atom()}
  def get_document_counterparties(<<_::288>> = document_id) do
    CounterParty
    |> where([cp], cp.content_id == ^document_id)
    |> preload([:content, :user])
    |> Repo.all()
  end

  def get_document_counterparties(_document_id), do: {:error, :invalid_id}

  @doc """
  Update counterparty status to signed
  """
  @spec counter_party_sign(CounterParty.t(), map(), String.t()) ::
          {:ok, CounterParty.t()} | {:error, Ecto.Changeset.t()} | {:error, String.t()}
  def counter_party_sign(
        counter_party,
        %{
          "ip_address" => ip_address,
          "signature_image" => signature_image
        },
        signed_file
      ) do
    counter_party
    |> CounterParty.sign_changeset(%{
      signature_status: :signed,
      signature_date: DateTime.utc_now(),
      signature_ip: ip_address,
      signature_image: signature_image,
      signed_file: signed_file
    })
    |> Repo.update()
  end

  def counter_party_sign(_, _), do: {:error, :invalid_data}

  def sign_document(%CounterParty{signature_status: :pending}, _),
    do: {:error, "Signatory has not accepted the document"}

  def sign_document(%CounterParty{signature_status: :signed}, _),
    do: {:error, "Document already signed"}
end
