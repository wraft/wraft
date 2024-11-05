defmodule WraftDocWeb.Plug.RateLimiter do
  @moduledoc """
  Plug that limits the number of requests a client can make to the API.
  """
  alias Plug.Conn

  @one_minute 60 * 1000
  @one_hour 60 * 60 * 1000
  @authenticated_requests 5000
  @unauthenticated_requests 500

  @doc false
  @spec init(Plug.opts()) :: Plug.opts()
  def init(opts), do: opts

  @doc """
  Limits the number of requests a client can make to the API.
  Primary rate limiting:
     based on user_id() : 5000 requests per hour
     based on ip(Unauthenticated Requests) : 5 requests per minute
  Secondary rate limiting: based on organisation_id()
  """
  @spec call(Plug.Conn.t(), Plug.opts()) :: Plug.Conn.t()
  def call(
        %Plug.Conn{
          private: %{phoenix_action: action, phoenix_controller: controller},
          assigns: %{current_user: %{current_org_id: organisation_id}}
        } = conn,
        opts
      ) do
    controller = controller |> Module.split() |> List.last()
    bucket = controller <> ":" <> action <> ":" <> organisation_id
    check_rate_limit(conn, bucket, opts[:scale], opts[:limit])
  end

  def call(%Plug.Conn{assigns: %{current_user: user}} = conn, _opts),
    do: check_rate_limit(conn, "user:" <> user.id, @one_hour, @authenticated_requests)

  def call(conn, _opts),
    do:
      check_rate_limit(
        conn,
        "anonymous:" <> remote_ip(conn),
        @one_minute,
        @unauthenticated_requests
      )

  # Private
  defp check_rate_limit(conn, bucket, scale_ms, limit) do
    bucket
    |> Hammer.check_rate(scale_ms, limit)
    |> case do
      {:allow, _count} ->
        conn

      {:deny, _limit} ->
        error_response(conn)
    end
  end

  defp error_response(conn) do
    error_message = Jason.encode!(%{errors: "Rate limit exceeded. Please try again later."})

    conn
    |> Conn.put_resp_content_type("application/json")
    |> Conn.send_resp(429, error_message)
    |> Conn.halt()
  end

  defp remote_ip(conn) do
    conn.remote_ip
    |> :inet_parse.ntoa()
    |> to_string()
  end
end
