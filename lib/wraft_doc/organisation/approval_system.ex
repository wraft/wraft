defmodule WraftDoc.Enterprise.ApprovalSystem do
  use Ecto.Schema
  import Ecto.Changeset

  schema "approval_system" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:approved, :boolean, default: false)
    field(:approved_log, :naive_datetime)
    belongs_to(:instance, WraftDoc.Document.Instance)
    belongs_to(:pre_state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:post_state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:approver, WraftDoc.Account.User)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:organisation, WraftDoc.Enterprise.Organisation)

    timestamps()
  end

  def changeset(approval_system, attrs \\ %{}) do
    approval_system
    |> cast(attrs, [
      :instance_id,
      :pre_state_id,
      :post_state_id,
      :approver_id,
      :user_id,
      :organisation_id
    ])
    |> validate_required([
      :instance_id,
      :pre_state_id,
      :post_state_id,
      :approver_id,
      :user_id,
      :organisation_id
    ])
  end

  def update_changeset(approval_system, attrs \\ %{}) do
    approval_system
    |> cast(attrs, [
      :instance_id,
      :pre_state_id,
      :post_state_id,
      :approver_id,
      :user_id,
      :organisation_id
    ])
    |> validate_required([
      :instance_id,
      :pre_state_id,
      :post_state_id,
      :approver_id
    ])
  end

  def approve_changeset(approval_system, attrs \\ %{}) do
    approval_system
    |> cast(attrs, [:approved, :approved_log])
    |> validate_required([:approved, :approved_log])
  end
end
