defmodule WraftDocWeb.Router do
  use WraftDocWeb, :router

  pipeline :browser do
    plug(:accepts, ["html"])
    plug(:fetch_session)
    plug(:fetch_flash)
    plug(:protect_from_forgery)
    plug(:put_secure_browser_headers)
  end

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :api_auth do
    plug(WraftDocWeb.Guardian.AuthPipeline)
  end

  scope "/", WraftDocWeb do
    # Use the default browser stack
    pipe_through(:api)
    get("/", PageController, :index)
  end

  # Scope which does not need authorization.
  scope "/api", WraftDocWeb do
    pipe_through(:api)

    # user
    scope "/v1", Api.V1, as: :v1 do
      resources("/users/signup", RegistrationController, only: [:create])
      post("/users/signin", UserController, :signin)
    end
  end

  # Scope which requires authorization.
  scope "/api", WraftDocWeb do
    pipe_through([:api, :api_auth])

    scope "/v1", Api.V1, as: :v1 do
      resources("/profile/:id", ProfileController, only: [:update])
      # Layout
      resources("/layouts", LayoutController, only: [:create, :index, :show, :update, :delete])
      # Content type
      resources("/content_types", ContentTypeController,
        only: [:create, :index, :show, :update, :delete]
      )

      # Engine
      resources("/engines", EngineController, only: [:index])
    end
  end

  scope "/api/swagger" do
    forward("/", PhoenixSwagger.Plug.SwaggerUI, otp_app: :wraft_doc, swagger_file: "swagger.json")
  end

  def swagger_info do
    %{
      info: %{
        version: "0.0.1",
        title: "Wraft Docs"
      },
      basePath: "/api/v1",
      securityDefinitions: %{
        Bearer: %{
          type: "apiKey",
          name: "Authorization",
          in: "header",
          description: "API Operations require a valid token."
        }
      },
      security: [
        # ApiKey is applied to all operations
        %{
          Bearer: []
        }
      ]
    }
  end
end
