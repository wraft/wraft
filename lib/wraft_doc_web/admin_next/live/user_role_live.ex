defmodule WraftDocWeb.AdminNext.UserRoleLive do
  @moduledoc """
  Backpex admin for `WraftDoc.Account.UserRole`.

  Mirrors `WraftDocWeb.UserRoleAdmin` (Kaffy):
  - Index columns: User name, Role name (via preload + display fields)
  - Form: select User + select Role
  - Index query: preload :user and :role
  """
  use Backpex.LiveResource,
    adapter: Backpex.Adapters.Ecto,
    adapter_config: [
      schema: WraftDoc.Account.UserRole,
      repo: WraftDoc.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3
    ],
    pubsub: [server: WraftDoc.PubSub]

  use WraftDocWeb.AdminNext.LiveResourcePage,
    subtitle: "Assignments of users to platform-wide roles."

  @impl Backpex.LiveResource
  def singular_name, do: "User Role"

  @impl Backpex.LiveResource
  def plural_name, do: "User Roles"

  @impl Backpex.LiveResource
  def layout(_assigns), do: {WraftDocWeb.AdminNext.Layouts, :app}

  @impl Backpex.LiveResource
  def fields do
    [
      user: %{
        module: Backpex.Fields.BelongsTo,
        label: "User",
        display_field: :name,
        live_resource: WraftDocWeb.AdminNext.UserLive,
        searchable: true
      },
      role: %{
        module: Backpex.Fields.BelongsTo,
        label: "Role",
        display_field: :name,
        live_resource: WraftDocWeb.AdminNext.UserRoleLive,
        searchable: true
      }
    ]
  end

  def changeset(user_role, attrs, _metadata) do
    WraftDoc.Account.UserRole.changeset(user_role, attrs)
  end
end
