defmodule WraftDoc.CounterParties do
  @moduledoc """
  Module that handles the repo connections of the counter parties context.
  """

  import Ecto.Query

  alias WraftDoc.CounterParties.CounterParty
  alias WraftDoc.Documents.Instance
  alias WraftDoc.Repo

  @doc """
  Get counterparty for a contract document
  """
  @spec get_counterparty(String.t(), String.t()) :: CounterParty.t() | nil
  def get_counterparty(document_id, counterparty_id) do
    Repo.get_by(CounterParty, content_id: document_id, counterparty_id: counterparty_id)
  end

  @doc """
  Get counterparty by email for a document
  """
  @spec get_counterparty_by_email(String.t(), String.t()) :: CounterParty.t() | nil
  def get_counterparty_by_email(document_id, email)
      when is_binary(document_id) and is_binary(email) do
    CounterParty
    |> where([cp], cp.content_id == ^document_id and cp.email == ^email)
    |> Repo.one()
  end

  @doc """
   Add counterparty to content
  """
  def add_counterparty(
        %Instance{id: content_id},
        %{
          "email" => email,
          "name" => name
        } = params
      ) do
    %CounterParty{}
    |> CounterParty.changeset(%{
      name: name,
      email: email,
      content_id: content_id,
      guest_user_id: Map.get(params, "guest_user_id")
    })
    |> Repo.insert()
    |> case do
      {:ok, counter_party} ->
        counter_party = Repo.preload(counter_party, [:guest_user, :content])
        {:ok, counter_party}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def add_counterparty(_, _), do: {:error, :invalid_params}

  @doc """
    Remove counterparty from content
  """
  @spec remove_counterparty(CounterParty.t()) ::
          {:ok, CounterParty.t()} | {:error, Ecto.Changeset.t()}
  def remove_counterparty(%CounterParty{} = counterparty) do
    Repo.delete(counterparty)
  end

  @doc """
  Get all counterparties for a document
  """
  @spec get_document_counterparties(String.t()) :: [CounterParty.t()]
  def get_document_counterparties(document_id) when is_binary(document_id) do
    CounterParty
    |> where([cp], cp.content_id == ^document_id)
    |> preload([:content, :guest_user])
    |> Repo.all()
  end
end
