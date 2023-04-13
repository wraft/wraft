defmodule WraftDocWeb.Api.V1.WaitingListController do
  use WraftDocWeb, :controller
  use PhoenixSwagger

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.WaitingLists
  alias WraftDoc.WaitingLists.WaitingList

  action_fallback(WraftDocWeb.FallbackController)

  def swagger_definitions do
    %{
      WaitingListRequest:
        swagger_schema do
          title("Join Waiting list")
          description("Join user to the waiting list")

          properties do
            first_name(:string, "User's first name", required: true)
            last_name(:string, "User's last name", required: true)
            email(:string, "User's email", required: true)
          end

          example(%{
            first_name: "first name",
            last_name: "last name",
            email: "sample@gmail.com"
          })
        end,
      WaitingListResponse:
        swagger_schema do
          title("Join Waiting list Info")
          description("Join Waiting list info")

          properties do
            info(:string, "Info")
          end

          example(%{
            info: "Success"
          })
        end
    }
  end

  @doc """
   Join waiting list
  """
  swagger_path :create do
    post("/waiting_list")
    summary("Join Waiting list")
    description("Waiting list join API")

    parameters do
      waiting_list(:body, Schema.ref(:WaitingListRequest), "User data for waiting list",
        required: true
      )
    end

    response(200, "Ok", Schema.ref(:WaitingListResponse))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    with nil <- Account.get_user_by_email(params["email"]),
         {:ok, %WaitingList{} = waiting_list} <- WaitingLists.join_waiting_list(params) do
      WaitingLists.waitlist_confirmation_email(waiting_list)

      conn
      |> put_resp_header("content-type", "application/json")
      |> send_resp(200, "Success")
    else
      %User{} ->
        {:error, "already in waitlist"}

      error ->
        error
    end
  end
end
