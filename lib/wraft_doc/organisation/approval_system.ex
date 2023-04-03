defmodule WraftDoc.Enterprise.ApprovalSystem do
  @moduledoc false

  use WraftDoc.Schema
  alias WraftDoc.Account.User
  alias WraftDoc.Enterprise.Flow
  alias WraftDoc.Enterprise.Flow.State

  schema "approval_system" do
    field(:name, :string)
    belongs_to(:pre_state, State)
    belongs_to(:post_state, State)
    belongs_to(:approver, User)
    belongs_to(:flow, Flow)
    belongs_to(:creator, User)
    has_many(:instance_approval_systems, WraftDoc.Document.InstanceApprovalSystem)
    timestamps()
  end

  # TODO include tests for both the given changesets here -> valid , invalid, constraints
  def changeset(approval_system, attrs \\ %{}) do
    approval_system
    |> cast(attrs, [
      :name,
      :pre_state_id,
      :post_state_id,
      :approver_id,
      :flow_id,
      :creator_id
    ])
    |> validate_required([
      :pre_state_id,
      :post_state_id,
      :approver_id,
      :flow_id,
      :creator_id
    ])
    |> organisation_constraint(State, :pre_state_id)
    |> organisation_constraint(State, :post_state_id)
    |> organisation_constraint(User, :approver_id)
    |> organisation_constraint(Flow, :flow_id)
  end

  def update_changeset(approval_system, attrs \\ %{}) do
    approval_system
    |> cast(attrs, [
      :name,
      :pre_state_id,
      :post_state_id,
      :approver_id
    ])
    |> validate_required([
      :pre_state_id,
      :post_state_id,
      :approver_id
    ])
    |> organisation_constraint(State, :pre_state_id)
    |> organisation_constraint(State, :post_state_id)
    |> organisation_constraint(User, :approver_id)
  end
end
