defmodule WraftDoc.Enterprise do
  @moduledoc """
  Module that handles the repo connections of the enterprise context.
  """
  import Ecto

  alias WraftDoc.{Repo, Enterprise.Flow, Account.User}

  @spec delete_flow(%Flow{}) :: %Flow{} | {:error, Ecto.Changeset.t()}
  def delete_flow(flow) do
    flow
    |> Changeset.change()
    |> Changeset.no_assoc_constraint(
      :instances,
      message:
        "Cannot delete the flow. Some Contents depend on this flow. Update those contents and then try again.!"
    )
    |> Repo.delete()
  end
end
