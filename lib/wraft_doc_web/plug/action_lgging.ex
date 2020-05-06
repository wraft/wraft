defmodule WraftDocWeb.Plug.AddActionLog do
  import Plug.Conn
  alias WraftDoc.{Repo, ActionLog}

  def init(_params) do
  end

  def call(conn, _params) do
    create_log(conn)
    conn
  end

  # Create log for an action.
  @spec create_log(Plug.Conn.t()) :: ActionLog.t()
  defp create_log(%Plug.Conn{assigns: %{current_user: _user}} = conn) do
    params = conn |> create_action_log_params()
    %ActionLog{} |> ActionLog.authorized_action_changeset(params) |> Repo.insert!()
  end

  defp create_log(conn) do
    params = conn |> create_action_log_params()
    %ActionLog{} |> ActionLog.unauthorized_action_changeset(params) |> Repo.insert!()
  end

  # Create params for action log.
  @spec create_action_log_params(Plug.Conn.t()) :: map
  defp create_action_log_params(
         %Plug.Conn{
           assigns: %{current_user: %{id: id} = user},
           method: method,
           request_path: path,
           remote_ip: ip,
           params: params
         } = conn
       ) do
    remote_ip = :inet_parse.ntoa(ip) |> to_string()
    [actor_agent] = get_req_header(conn, "user-agent")
    action = conn.private.phoenix_action |> Atom.to_string()

    %{
      actor: user,
      user_id: id,
      request_path: path,
      request_method: method,
      params: params,
      remote_ip: remote_ip,
      actor_agent: actor_agent,
      action: action
    }
  end

  defp create_action_log_params(
         %Plug.Conn{method: method, request_path: path, remote_ip: ip, params: params} = conn
       ) do
    remote_ip = :inet_parse.ntoa(ip) |> to_string()
    actor_agent = get_req_header(conn, "user-agent")
    action = conn.private.phoenix_action |> Atom.to_string()

    %{
      request_path: path,
      request_method: method,
      params: params,
      remote_ip: remote_ip,
      actor_agent: actor_agent,
      action: action
    }
  end
end
