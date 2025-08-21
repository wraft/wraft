defmodule WraftDoc.Enterprise.Flow do
  @moduledoc """
    The work flow model.
  """
  @behaviour ExTypesense

  use WraftDoc.Schema

  alias __MODULE__

  schema "flow" do
    field(:name, :string)
    field(:controlled, :boolean, default: false)
    field(:control_data, :map)
    belongs_to(:creator, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)
    has_many(:states, WraftDoc.Enterprise.Flow.State, preload_order: [asc: :order])
    has_many(:approval_systems, WraftDoc.Enterprise.ApprovalSystem)
    timestamps()
  end

  def changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :controlled, :organisation_id])
    |> validate_required([:name, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def controlled_changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :controlled, :control_data, :organisation_id])
    |> validate_required([:name, :controlled, :control_data, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def update_changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :organisation_id])
    |> validate_required([:name, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def update_controlled_changeset(%Flow{} = flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [:name, :controlled, :control_data, :organisation_id])
    |> validate_required([:name, :control_data, :organisation_id])
    |> unique_constraint(:name,
      message: "Flow already created.!",
      name: :flow_organisation_unique_index
    )
  end

  def align_order_changeset(flow, attrs \\ %{}) do
    flow
    |> cast(attrs, [])
    |> cast_assoc(:states, with: &Flow.State.order_update_changeset/2)
  end

  @impl ExTypesense
  def get_field_types do
    %{
      enable_nested_fields: true,
      fields: [
        %{name: "internal_id", type: "string", facet: false},
        %{name: "name", type: "string", facet: false},
        %{name: "controlled", type: "bool", facet: true},
        %{name: "creator_id", type: "string", facet: true},
        %{name: "organisation_id", type: "string", facet: true},
        %{name: "inserted_at", type: "int64", facet: false},
        %{name: "updated_at", type: "int64", facet: false}
      ]
    }
  end
end
