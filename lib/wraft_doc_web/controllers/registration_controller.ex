defmodule WraftDocWeb.Api.V1.RegistrationController do
  use WraftDocWeb, :controller
  use PhoenixSwagger
  import Ecto.Query, warn: false
  action_fallback(WraftDocWeb.FallbackController)
  alias WraftDoc.{Account, Account.User, Enterprise.Organisation}

  def swagger_definitions do
    %{
      UserRegisterRequest:
        swagger_schema do
          title("Register User")
          description("A user to be registered in the application")

          properties do
            name(:string, "User's name", required: true)
            email(:string, "User's email", required: true)
            password(:string, "User's password", required: true)
          end

          example(%{
            name: "John Doe",
            email: "email@xyz.com",
            password: "Password"
          })
        end
    }
  end

  @doc """
    New registration.
  """
  swagger_path :create do
    post("/users/signup/")
    summary("User registration")
    description("User registration API")
    operation_id("create_user")
    tag("Registration")

    parameters do
      token(:query, :string, "Token obtained from invitation mail")
      user(:body, Schema.ref(:UserRegisterRequest), "User to register", required: true)
    end

    response(200, "Ok", Schema.ref(:UserToken))
    response(422, "Unprocessable Entity", Schema.ref(:Error))
  end

  @spec create(Plug.Conn.t(), map) :: Plug.Conn.t()
  def create(conn, params) do
    with {:ok, %Organisation{} = org, params} <- Account.get_organisation_from_token(params),
         %User{} = user <- Account.registration(params, org),
         {:ok, token, _claims} <-
           Account.authenticate(%{user: user, password: params["password"]}) do
      conn
      |> put_status(:created)
      |> render("create.json", user: user, token: token)
    end
  end
end
