defmodule WraftDoc.Documents.InstanceApprovalSystem do
  @moduledoc """
  Schema module for instance approval system
  * Flag -  to denote wether it is approved or not
  * Order -  Order as per states order
  * approved_at - Date and time of approved at
  * instance_id -  Id of instance ot approve
  * approval_system_id - Approval system to follow
  """
  use WraftDoc.Schema

  schema "instance_approval_system" do
    field(:flag, :boolean, default: false)
    field(:approved_at, :naive_datetime)
    field(:rejected_at, :naive_datetime)
    belongs_to(:instance, WraftDoc.Documents.Instance)
    belongs_to(:approval_system, WraftDoc.Enterprise.ApprovalSystem)
    has_one(:approver, through: [:approval_system, :approver])
    timestamps()
  end

  # TODO write tests for the changesets
  def changeset(instance_approval_system, attrs) do
    instance_approval_system
    |> cast(attrs, [:instance_id, :approval_system_id])
    |> validate_required([:instance_id, :approval_system_id])
  end

  def update_changeset(instance_approval_system, attrs) do
    instance_approval_system
    |> cast(attrs, [:flag, :approved_at, :rejected_at])
    |> validate_required([:flag])
  end
end
