defmodule WraftDocWeb.UserSocket do
  @moduledoc """
  User socket module
  """
  use Phoenix.Socket

  ## Channels
  channel("notification:*", WraftDocWeb.NotificationChannel)

  # channel("room:*", WraftDocWeb.NotificationChannel)

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  # def connect(_params, socket) do
  #   {:ok, socket}
  # end
  @impl true
  def connect(_params, socket, _conntection_info) do
    {:ok, socket}
  end

  # This function will be called when there was no authentication information
  @impl true
  def connect(_params, _socket) do
    :error
  end

  # def id(socket), do: socket.assigns[:current_user].id |> to_string()
  @impl true
  def id(socket) do
    socket = socket.assigns[:current_user].id
    to_string(socket)
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "user_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     WraftDocWeb.Endpoint.broadcast("user_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
end
