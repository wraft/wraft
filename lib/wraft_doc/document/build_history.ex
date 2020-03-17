defmodule WraftDoc.Document.Instance.History do
  @moduledoc """
    The instance build history model.
  """
  use Ecto.Schema
  import Ecto.Changeset
  alias __MODULE__

  schema "build_history" do
    field(:uuid, Ecto.UUID, autogenerate: true, null: false)
    field(:status, :string, null: false)
    field(:exit_code, :integer, null: false)
    field(:start_time, :naive_datetime, null: false)
    field(:end_time, :naive_datetime, null: false)
    field(:delay, :integer, null: false)
    belongs_to(:content, WraftDoc.Document.Instance)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%History{} = history, attrs \\ %{}) do
    history
    |> cast(attrs, [:status, :exit_code, :start_time, :end_time, :delay])
    |> validate_required([:status, :exit_code, :start_time, :end_time, :delay])
  end
end
