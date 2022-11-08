defmodule WraftDoc.Document.Instance.History do
  @moduledoc """
    The instance build history model.
  """
  use WraftDoc.Schema

  alias __MODULE__

  schema "build_history" do
    field(:status, :string)
    field(:exit_code, :integer)
    field(:start_time, :naive_datetime)
    field(:end_time, :naive_datetime)
    field(:delay, :integer)
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
