defmodule WraftDocWeb.Api.V1.RegistrationController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import Ecto.Query, warn: false

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.Notifications.Delivery
  alias WraftDocWeb.Schemas

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Registration"])

  @doc """
    New registration.
  """
  operation(:create,
    summary: "User registration",
    description: "User registration API",
    request_body:
      {"User registration data", "multipart/form-data", Schemas.Registration.UserRegisterRequest},
    parameters: [
      token: [in: :query, type: :string, description: "Token obtained from invitation mail"]
    ],
    responses: [
      ok: {"Ok", "application/json", Schemas.User.UserToken},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Schemas.Error},
      unauthorized: {"Unauthorized for Access", "application/json", Schemas.Error}
    ]
  )

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    case FunWithFlags.enabled?(:waiting_list_registration_control, for: %{email: params["email"]}) do
      true ->
        with {:ok,
              %{organisations: organisations, user: %User{id: user_id, name: user_name} = user}} <-
               Account.registration(params),
             %{user: user, tokens: [access_token: access_token, refresh_token: refresh_token]} <-
               Account.authenticate(%{user: user, password: params["password"]}) do
          Task.start(fn ->
            Delivery.dispatch(user, "registration.user_joins_wraft", %{
              user_name: user_name,
              channel: :user_notification,
              channel_id: user_id,
              metadata: %{user_id: user_id, type: "registration"}
            })
          end)

          conn
          |> put_status(:created)
          |> render("create.json",
            user: user,
            access_token: access_token,
            refresh_token: refresh_token,
            organisations: organisations
          )
        end

      false ->
        conn
        |> put_resp_header("content-type", "application/json")
        |> send_resp(401, Jason.encode!("Given email is not approved!"))
    end
  end
end
