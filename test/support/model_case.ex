defmodule WraftDoc.ModelCase do
  @moduledoc """
  This module defines the test case to be used by
  model tests.
  You may define functions here to be used as helpers in
  your model tests. See `errors_on/2`'s definition as reference.
  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias WraftDoc.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      # import WraftDoc.TestHelpers
      import WraftDoc.ModelCase
    end
  end

  setup tags do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(WraftDoc.Repo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
    :ok
  end

  @doc """
  Helper for returning list of errors in a struct when given certain data.
  ## Examples
  Given a User schema that lists `:name` as a required field and validates
  `:password` to be safe, it would return:
      iex> errors_on(%User{}, %{password: "password"})
      [password: "is unsafe", name: "is blank"]
  You could then write your assertion like:
      assert {:password, "is unsafe"} in errors_on(%User{}, %{password: "password"})
  You can also create the changeset manually and retrieve the errors
  field directly:
      iex> changeset = User.changeset(%User{}, password: "password")
      iex> {:password, "is unsafe"} in changeset.errors
      true
  """

  # def errors_on(struct, data) do
  #   struct.__struct__.changeset(struct, data)
  #   |> Ecto.Changeset.traverse_errors(&WraftDoc.ErrorHelpers.translate_error/1)
  #   |> Enum.flat_map(fn {key, errors} -> for msg <- errors, do: {key, msg} end)
  # end

  def errors_on(changeset, field) do
    for {message, opts} <- Keyword.get_values(changeset.errors, field) do
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end
  end
end
