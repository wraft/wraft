defmodule WraftDoc.Document.Approval do
  @moduledoc """
  Module that handles the repo connections of the document context.
  """

  import Ecto.Query
  alias WraftDoc.Repo
  alias WraftDoc.Document.InstanceTransitionLog
  alias WraftDoc.Account.User

  @doc """
  Fetches the approval history for a document.
  """

  @spec get_document_approval_history(Ecto.UUID.t(), User.t()) ::
          {:ok, list(InstanceApprovalSystem.t())} | {:error, :not_found}
  def get_document_approval_history(<<_::288>> = document_id) do
    query =
      from ias in InstanceTransitionLog,
        where: ias.instance_id == ^document_id,
        preload: [:to_state, reviewer: [:profile]],
        order_by: [desc: ias.inserted_at]

    case Repo.all(query) do
      [] -> {:error, :not_found}
      history -> {:ok, history}
    end
  end

  def get_document_approval_history(_, _), do: {:error, :not_found}
end