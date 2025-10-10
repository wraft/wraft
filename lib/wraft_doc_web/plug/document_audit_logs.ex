defmodule WraftDocWeb.Plug.AddDocumentAuditLog do
  @moduledoc """
  Plug for creating and storing document-specific audit logs.
  Runs in controller actions where a document is created, updated, deleted, etc.
  """

  import Plug.Conn
  alias WraftDoc.Documents.DocumentAuditLog
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo

  def init(_params), do: nil

  def call(conn, _params) do
    register_before_send(conn, fn conn ->
      Task.start(fn -> create_log(conn) end)
      conn
    end)
  end

  @spec create_log(Plug.Conn.t()) :: ActionLog.t() | nil
  defp create_log(conn) do
    params = create_audit_log_params(conn)

    %DocumentAuditLog{}
    |> DocumentAuditLog.changeset(params)
    |> Repo.insert!()
  end

  @spec create_audit_log_params(Plug.Conn.t()) :: map()
  defp create_audit_log_params(
         %Plug.Conn{
           assigns: %{
             current_user: %{id: user_id, name: user_name, current_org_id: current_org_id} = user
           },
           method: method,
           request_path: path,
           remote_ip: ip,
           params: params
         } = conn
       ) do
    remote_ip = ip |> :inet_parse.ntoa() |> to_string()
    actor_agent = conn |> get_req_header("user-agent") |> List.first()
    action = Atom.to_string(conn.private.phoenix_action)

    organisation =
      if current_org_id do
        Repo.get(Organisation, current_org_id)
      else
        nil
      end

    %{
      document_id: params["id"],
      user_id: user_id,
      actor: Map.put(user, :organisation, organisation),
      action: action,
      message: log_message(conn, user_name, action),
      changes: conn.assigns[:changes] || %{},
      request_path: path,
      request_method: method,
      params: change_structs_to_maps(params),
      remote_ip: remote_ip,
      actor_agent: actor_agent
    }
  end

  defp change_structs_to_maps(params) do
    Enum.reduce(params, %{}, fn
      {k, %{__struct__: _} = v}, acc -> Map.put(acc, k, Map.from_struct(v))
      {k, v}, acc -> Map.put(acc, k, v)
    end)
  end

  defp log_message(conn, user_name, action) do
    cond do
      conn.assigns[:audit_log_message] ->
        conn.assigns[:audit_log_message]

      action == "build" ->
        "#{user_name} generated document"

      action == "generate_signature" ->
        "#{user_name} generated document for signature"

      # TODO add info about invited counterparty
      action == "add_counterparty" ->
        "#{user_name} added counterparty"

      action == "request_signature" ->
        "#{user_name} requested signature"

      action == "apply_signature" ->
        "#{user_name} applied signature"

      true ->
        "#{action}d by #{user_name}"
    end
  end
end
