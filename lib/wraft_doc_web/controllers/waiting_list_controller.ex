defmodule WraftDocWeb.Api.V1.WaitingListController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.WaitingLists
  alias WraftDoc.WaitingLists.WaitingList
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.WaitingList, as: WaitingListSchema

  action_fallback(WraftDocWeb.FallbackController)

  tags(["WaitingList"])

  operation(:create,
    summary: "Join Waiting list",
    description: "Waiting list join API",
    request_body:
      {"User data for waiting list", "application/json", WaitingListSchema.WaitingListRequest},
    responses: [
      ok: {"Ok", "application/json", WaitingListSchema.WaitingListResponse},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    with user <- Account.get_user_by_email(params["email"]),
         true <- is_nil(user) or user.is_guest,
         {:ok, %WaitingList{} = waiting_list} <- WaitingLists.join_waiting_list(params) do
      WaitingLists.waitlist_confirmation_email(waiting_list)

      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, "Success")
    else
      %User{} ->
        {:error, "already a member of wraft"}

      false ->
        {:error, "already a member of wraft"}

      error ->
        error
    end
  end
end
