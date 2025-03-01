defmodule WraftDoc.CounterParties do
  @moduledoc """
  Module that handles the repo connections of the counter parties context.
  """

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
   Add counterparty to content
  """
  def add_counterparty(%Instance{id: content_id}, %{
        "guest_user_id" => guest_user_id,
        "name" => name
      }) do
    CounterParties
    |> CounterParty.changeset(%{
      name: name,
      content_id: content_id,
      guest_user_id: guest_user_id
    })
    |> Repo.insert()
    |> case do
      {:ok, counter_party} ->
        Repo.preload(counter_party, [:guest_user, :content])

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def add_counterparty(_, _), do: nil

  @doc """
    Remove counterparty from content
  """
  @spec remove_counterparty(CounterParty.t()) ::
          {:ok, CounterParty.t()} | {:error, Ecto.Changeset.t()}
  def remove_counterparty(%CounterParty{} = counterparty) do
    Repo.delete(counterparty)
  end
end
