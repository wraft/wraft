defmodule RoleUUID do
  alias WraftDoc.{Repo, Account.Role}
  import Ecto.Changeset

  def all_roles do
    Repo.all(Role) |> Enum.each(fn x -> add_uuid(x) end)
  end

  def add_uuid(role) do
    role |> cast(%{uuid: Ecto.UUID.generate()}, [:uuid]) |> Repo.update!()
  end
end

RoleUUID.all_roles()