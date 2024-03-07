defmodule WraftDocWeb.Api.V1.InstanceView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.{
    ContentTypeView,
    InstanceApprovalSystemView,
    InstanceVersionView,
    StateView,
    UserView,
    VendorView
  }

  alias __MODULE__

  def render("create.json", %{content: content}) do
    %{
      content: %{
        id: content.id,
        instance_id: content.instance_id,
        raw: content.raw,
        serialized: content.serialized,
        inserted_at: content.inserted_at,
        updated_at: content.updated_at
      },
      content_type:
        render_one(content.content_type, ContentTypeView, "content_type.json", as: :content_type),
      state: render_one(content.state, StateView, "create.json", as: :state),
      vendor: render_one(content.vendor, VendorView, "vendor.json", as: :vendor),
      instance_approval_systems:
        render_many(content.instance_approval_systems, InstanceApprovalSystemView, "create.json",
          as: :instance_approval_system
        ),
      profile_pic: generate_url(content.creator.profile),
      creator: render_one(content.creator, UserView, "user_id_and_name.json", as: :user)
    }
  end

  def render("instance.json", %{instance: instance}) do
    %{
      id: instance.id,
      instance_id: instance.instance_id,
      raw: instance.raw,
      serialized: instance.serialized,
      build: instance.build,
      editable: instance.editable,
      inserted_at: instance.inserted_at,
      updated_at: instance.updated_at
    }
  end

  def render("index.json", %{
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      contents: render_many(contents, InstanceView, "create.json", as: :content),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("approvals_index.json", %{
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      pending_approvals:
        render_many(contents, InstanceView, "pending_approvals.json", as: :content),
      page_number: page_number,
      total_pages: total_pages,
      total_entries: total_entries
    }
  end

  def render("pending_approvals.json", %{content: content}) do
    %{
      content: %{
        id: content.id,
        instance_id: content.instance_id,
        raw: content.raw,
        serialized: content.serialized,
        previous_state: content.previous_state,
        next_state: content.next_state,
        inserted_at: content.inserted_at,
        updated_at: content.updated_at
      },
      state: render_one(content.state, StateView, "create.json", as: :state),
      creator: render_one(content.creator, UserView, "user_id_and_name.json", as: :user)
    }
  end

  def render("show.json", %{instance: instance}) do
    %{
      content: render_one(instance, InstanceView, "instance.json", as: :instance),
      content_type:
        render_one(instance.content_type, ContentTypeView, "c_type_with_layout.json",
          as: :content_type
        ),
      state: render_one(instance.state, StateView, "instance_state.json", as: :state),
      creator: render_one(instance.creator, UserView, "user.json", as: :user),
      profile_pic: generate_url(instance.creator.profile),
      versions: render_many(instance.versions, InstanceVersionView, "version.json", as: :version),
      instance_approval_systems:
        render_many(instance.instance_approval_systems, InstanceApprovalSystemView, "create.json",
          as: :instance_approval_system
        )
    }
  end

  def render("approve_or_reject.json", %{instance: instance}) do
    %{
      content: render_one(instance, InstanceView, "instance.json", as: :instance),
      content_type:
        render_one(instance.content_type, ContentTypeView, "c_type_with_layout.json",
          as: :content_type
        ),
      state: render_one(instance.state, StateView, "state.json", as: :state),
      creator: render_one(instance.creator, UserView, "user.json", as: :user),
      profile_pic: generate_url(instance.creator.profile),
      versions: render_many(instance.versions, InstanceVersionView, "version.json", as: :version)
    }
  end

  def render("build_fail.json", %{exit_code: exit_code}) do
    %{
      info: "Build failed",
      exit_code: exit_code
    }
  end

  def generate_url(%{profile_pic: pic} = profile) do
    WraftDocWeb.PropicUploader.url({pic, profile}, signed: true)
  end
end
