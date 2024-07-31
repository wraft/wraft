defmodule WraftDoc.Document.Approval do
  @moduledoc """
  Module that handles the repo connections of the document Approval context.
  """

  import Ecto.Query
  alias WraftDoc.Document.InstanceTransitionLog
  alias WraftDoc.Repo

  @doc """
  Fetches the approval history for a document.
  """

  @spec get_document_approval_history(Ecto.UUID.t()) ::
          {:ok, list(InstanceApprovalSystem.t())} | {:error, :not_found}
  def get_document_approval_history(<<_::288>> = document_id) do
    InstanceTransitionLog
    |> where([ias], ias.instance_id == ^document_id)
    |> preload([ias], [:to_state, reviewer: [:profile]])
    |> order_by([ias], desc: ias.inserted_at)
    |> Repo.all()
    |> case do
      [] -> nil
      history -> {:ok, history}
    end
  end

  def get_document_approval_history(_, _), do: {:error, :not_found}
end
