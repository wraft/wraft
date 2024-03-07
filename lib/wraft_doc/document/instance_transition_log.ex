defmodule WraftDoc.Document.InstanceTransitionLog do
  @moduledoc """
    Log to keep track state transition of Instance
  """
  use WraftDoc.Schema

  alias __MODULE__

  @review_statuses [:approved, :rejected]
  @fields ~w(review_status reviewed_at from_state_id to_state_id reviewer_id instance_id)a

  schema "instance_transition_log" do
    field(:review_status, Ecto.Enum, values: @review_statuses)
    field(:reviewed_at, :naive_datetime)
    belongs_to(:from_state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:to_state, WraftDoc.Enterprise.Flow.State)
    belongs_to(:reviewer, WraftDoc.Account.User)
    belongs_to(:instance, WraftDoc.Document.Instance)

    timestamps()
  end

  def changeset(%InstanceTransitionLog{} = instance_transition_log, attrs \\ %{}) do
    instance_transition_log
    |> cast(attrs, @fields)
    |> validate_required(@fields)
  end
end
