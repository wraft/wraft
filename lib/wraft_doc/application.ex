defmodule WraftDoc.Application do
  @moduledoc false
  use Application
  # alias WraftDoc.Notifications.Listener

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @impl true
  def start(_type, _args) do
    # Define workers and child supervisors to be supervised
    children = [
      # Start the Ecto repository
      WraftDoc.Repo,
      # Start the endpoint when the application starts
      WraftDocWeb.Endpoint,
      # PubSub added here after updated to phoenix 1.6.4
      {Phoenix.PubSub, [name: WraftDoc.PubSub, adapter: Phoenix.PubSub.PG2]},
      WraftDoc.Search.TypesenseServer,
      # Start your own worker by calling: WraftDoc.Worker.start_link(arg1, arg2, arg3)
      # worker(WraftDoc.Worker, [arg1, arg2, arg3]),
      {Oban, oban_config()},
      {Task.Supervisor, name: WraftDoc.TaskSupervisor},
      # To sweep expired tokens from your db.
      # {Guardian.DB.Token.SweeperServer, []},
      # worker(WraftDoc.Notifications, ["content_type_changes"], id: :content_type_changes)
      # worker(
      #   WraftDoc.Notifications.Listener,
      #   ["content_type_changes", [name: WraftDoc.Notifications.Listener]],
      #   restart: :permanent
      # )
      WraftDoc.Schedulers.RefreshDashboardStats,
      WraftDoc.Utils.Vault
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: WraftDoc.Supervisor]

    Logger.add_backend(Sentry.LoggerBackend)

    Supervisor.start_link(children, opts)
  end

  # Conditionally disable queues or plugins here.
  defp oban_config do
    Application.fetch_env!(:wraft_doc, Oban)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    WraftDocWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
