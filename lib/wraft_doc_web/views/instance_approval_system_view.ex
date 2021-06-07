defmodule WraftDocWeb.Api.V1.InstanceApprovalSystemView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.{ApprovalSystemView, InstanceView, UserView}

  def render("instance_approval_system.json", %{
        instance_approval_system: instance_approval_system
      }) do
    %{
      id: instance_approval_system.id,
      flag: instance_approval_system.flag,
      order: instance_approval_system.order,
      approved_at: instance_approval_system.approved_at,
      instance_id: instance_approval_system.instance_id,
      approval_system_id: instance_approval_system.approval_system_id
    }
  end

  def render("create.json", %{instance_approval_system: instance_approval_system}) do
    %{
      instance_approval_system:
        render_one(instance_approval_system, __MODULE__, "instance_approval_system.json",
          as: :instance_approval_system
        ),
      approver: render_one(instance_approval_system.approver, UserView, "user.json", as: :user)
    }
  end

  def render("show.json", %{instance_approval_system: instance_approval_system}) do
    %{
      instance_approval_system:
        render_one(instance_approval_system, __MODULE__, "instance_approval_system.json",
          as: :instance_approval_system
        ),
      instance:
        render_one(instance_approval_system.instance, InstanceView, "instance.json", as: :instance),
      approval_system:
        render_one(
          instance_approval_system.approval_system,
          ApprovalSystemView,
          "approval_system.json",
          as: :approval_system
        )
    }
  end

  def render("index.json", %{
        instance_approval_systems: instance_approval_systems,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      instance_approval_systems:
        render_many(instance_approval_systems, __MODULE__, "show.json",
          as: :instance_approval_system
        ),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end
end
