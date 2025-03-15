defmodule WraftDoc.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :wraft_doc

  def seed do
    ensure_started()

    {:ok, _, _} =
      Ecto.Migrator.with_repo(WraftDoc.Repo, fn _repo ->
        path = :wraft_doc |> :code.priv_dir() |> Path.join("repo/seeds.exs")

        if File.exists?(path) do
          IO.puts("Running seed file...")
          Code.eval_file(path)
        else
          raise ArgumentError, "Could not find seed file at #{path}"
        end
      end)
  end

  def migrate do
    ensure_started()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def createdb do
    ensure_started()

    for repo <- repos() do
      :ok = ensure_repo_created(repo)
    end

    IO.puts("Creation of Db successful!")
  end

  def rollback(repo, version) do
    ensure_started()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  def wraft_permissions do
    ensure_started()
    Mix.Tasks.Wraft.Permissions.run([])
  end

  # defp repos do
  #   Application.fetch_env!(@app, :ecto_repos)
  # end

  defp repos do
    Application.load(@app)
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp ensure_started do
    Application.ensure_all_started(:ssl)
    Application.ensure_all_started(:faker)
  end

  defp ensure_repo_created(repo) do
    IO.puts("create #{inspect(repo)} database if it doesn't exist")

    case repo.__adapter__.storage_up(repo.config) do
      :ok -> :ok
      {:error, :already_up} -> :ok
      {:error, term} -> {:error, term}
    end
  end
end
