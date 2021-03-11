defmodule WraftDocWeb.Plug.AddActionLog do
  @moduledoc """
  Plug for creating and storing action log.
  """

  import Plug.Conn
  alias WraftDoc.{ActionLog, Repo}

  def init(_params) do
  end

  def call(conn, _params) do
    create_log(conn)
    conn
  end

  # Create log for an action.
  @spec create_log(Plug.Conn.t()) :: ActionLog.t()
  defp create_log(%Plug.Conn{assigns: %{current_user: _user}} = conn) do
    params = create_action_log_params(conn)
    %ActionLog{} |> ActionLog.authorized_action_changeset(params) |> Repo.insert!()
  end

  defp create_log(conn) do
    params = create_action_log_params(conn)
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
    remote_ip = ip |> :inet_parse.ntoa() |> to_string()
    actor_agent = conn |> get_req_header("user-agent") |> List.first()
    action = Atom.to_string(conn.private.phoenix_action)
    params = change_structs_to_maps(params)

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
    remote_ip = ip |> :inet_parse.ntoa() |> to_string()
    actor_agent = conn |> get_req_header("user-agent") |> List.first()
    action = Atom.to_string(conn.private.phoenix_action)
    params = change_structs_to_maps(params)

    %{
      request_path: path,
      request_method: method,
      params: params,
      remote_ip: remote_ip,
      actor_agent: actor_agent,
      action: action
    }
  end

  # Change the stucts in params to maps.
  @spec change_structs_to_maps(map) :: map
  defp change_structs_to_maps(params) do
    Enum.reduce(params, %{}, fn
      {k, %{__struct__: _} = v}, acc ->
        Map.put(acc, k, Map.from_struct(v))

      {k, v}, acc ->
        Map.put(acc, k, v)
    end)
  end
end
