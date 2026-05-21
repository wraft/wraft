defmodule WraftDoc.Documents.Instance.History do
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
    field(:error_log, :string)
    belongs_to(:content, WraftDoc.Documents.Instance)
    belongs_to(:creator, WraftDoc.Account.User)
    timestamps()
  end

  def changeset(%History{} = history, attrs \\ %{}) do
    history
    |> cast(attrs, [:status, :exit_code, :start_time, :end_time, :delay, :error_log])
    |> validate_required([:status, :exit_code, :start_time, :end_time, :delay])
  end
end
