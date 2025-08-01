defmodule WraftDocWeb.Api.V1.InstanceView do
  use WraftDocWeb, :view

  alias WraftDocWeb.Api.V1.ContentTypeView
  alias WraftDocWeb.Api.V1.FlowView
  alias WraftDocWeb.Api.V1.InstanceApprovalSystemView
  alias WraftDocWeb.Api.V1.InstanceVersionView
  alias WraftDocWeb.Api.V1.StateView
  alias WraftDocWeb.Api.V1.UserView
  alias WraftDocWeb.Api.V1.VendorView
  alias __MODULE__

  def render("create.json", %{content: content}) do
    %{
      content: %{
        id: content.id,
        instance_id: content.instance_id,
        meta: content.meta,
        raw: content.raw,
        approval_status: content.approval_status,
        type: content.type,
        serialized: content.serialized,
        vendor: render_one(content.vendor, VendorView, "vendor.json", as: :vendor),
        inserted_at: content.inserted_at,
        updated_at: content.updated_at
      },
      content_type:
        render_one(content.content_type, ContentTypeView, "content_type.json", as: :content_type),
      state: render_one(content.state, StateView, "create.json", as: :state),
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
      meta: instance.meta,
      instance_id: instance.instance_id,
      approval_status: instance.approval_status,
      raw: instance.raw,
      serialized: instance.serialized,
      build: instance.build,
      signed_doc_url: instance.signed_doc_url,
      editable: instance.editable,
      vendor: render_one(instance.vendor, VendorView, "vendor.json", as: :vendor),
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

  def render("instance_summary.json", %{content: content}) do
    %{
      content: %{
        id: content.id,
        instance_id: content.instance_id,
        meta: content.meta,
        approval_status: content.approval_status,
        type: content.type,
        title: get_in(content.serialized, ["title"]),
        vendor: render_one(content.vendor, VendorView, "vendor.json", as: :vendor),
        inserted_at: content.inserted_at,
        updated_at: content.updated_at
      },
      content_type:
        render_one(content.content_type, ContentTypeView, "content_type.json", as: :content_type),
      state: render_one(content.state, StateView, "create.json", as: :state),
      flow:
        render_one(content.content_type.flow, FlowView, "flow_states_summary.json", as: :flow),
      instance_approval_systems:
        render_many(content.instance_approval_systems, InstanceApprovalSystemView, "create.json",
          as: :instance_approval_system
        ),
      profile_pic: generate_url(content.creator.profile),
      creator: render_one(content.creator, UserView, "user_id_and_name.json", as: :user)
    }
  end

  def render("instance_summaries_paginated.json", %{
        contents: contents,
        page_number: page_number,
        total_pages: total_pages,
        total_entries: total_entries
      }) do
    %{
      contents: render_many(contents, InstanceView, "instance_summary.json", as: :content),
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
        title: get_in(content.serialized, ["title"]),
        previous_state: content.previous_state,
        next_state: content.next_state,
        inserted_at: content.inserted_at,
        updated_at: content.updated_at
      },
      state: render_one(content.state, StateView, "create.json", as: :state),
      creator: render_one(content.creator, UserView, "user_id_and_name.json", as: :user)
    }
  end

  def render("meta.json", %{meta: meta}), do: %{meta: meta}

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
      vendor: render_one(instance.vendor, VendorView, "vendor.json", as: :vendor),
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

  def render("build_fail.json", %{exit_code: exit_code, error: error}) do
    %{
      info: "Build failed",
      error: error,
      exit_code: exit_code
    }
  end

  def render("email.json", %{info: info}) do
    %{
      info: info
    }
  end

  def render("check_token.json", %{token: _}) do
    %{
      info: "Token is valid"
    }
  end

  def render("contract_chart.json", %{contract_list: contract_list}), do: contract_list

  def generate_url(%{profile_pic: pic} = profile) do
    WraftDocWeb.PropicUploader.url({pic, profile}, signed: true)
  end
end
