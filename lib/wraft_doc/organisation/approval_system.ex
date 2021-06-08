defmodule WraftDoc.Enterprise.ApprovalSystem do
  @moduledoc false

  use WraftDoc.Schema
  alias __MODULE__
  import Ecto.Query
  alias WraftDoc.{Account.User, Enterprise.Flow, Enterprise.Flow.State}

  @derive {Jason.Encoder, only: [:name]}
  defimpl Spur.Trackable, for: ApprovalSystem do
    def actor(approval_system), do: "#{approval_system.creator_id}"
    def object(approval_system), do: "ApprovalSystem:#{approval_system.id}"
    def target(_), do: nil

    def audience(%{flow_id: id}) do
      from(u in User,
        join: f in Flow,
        where: f.id == ^id,
        where: u.organisation_id == f.organisation_id
      )
    end
  end

  schema "approval_system" do
    field(:name, :string)
    belongs_to(:pre_state, State)
    belongs_to(:post_state, State)
    belongs_to(:approver, User)
    belongs_to(:flow, Flow)
    belongs_to(:creator, User)
    timestamps()
  end

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
