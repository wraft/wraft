defmodule WraftDocWeb.Api.V1.ProfileController do
  use WraftDocWeb, :controller
  use OpenApiSpex.ControllerSpecs

  plug(WraftDocWeb.Plug.AddActionLog)
  import Ecto.Query, warn: false
  alias WraftDoc.{Account, Account.Profile}
  alias WraftDocWeb.Schemas.Error
  alias WraftDocWeb.Schemas.Profile, as: ProfileSchema

  action_fallback(WraftDocWeb.FallbackController)

  tags(["Profile"])

  operation(:update,
    summary: "update users profile",
    description: "Update users profile",
    operation_id: "update_profile",
    request_body:
      {"Profile update data", "multipart/form-data",
       %OpenApiSpex.Schema{
         type: :object,
         properties: %{
           name: %OpenApiSpex.Schema{type: :string, description: "Name"},
           profile_pic: %OpenApiSpex.Schema{
             type: :string,
             format: :binary,
             description: "Profile pic"
           },
           dob: %OpenApiSpex.Schema{type: :string, format: "date", description: "Date of Birth"},
           gender: %OpenApiSpex.Schema{type: :string, description: "Gender"}
         },
         required: [:name, :gender]
       }},
    responses: [
      ok: {"Updated", "application/json", ProfileSchema.Profile},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  @spec update(Plug.Conn.t(), map) :: Plug.Conn.t()
  def update(conn, params) do
    current_user = conn.assigns[:current_user]

    with %Profile{} = profile <- Account.update_profile(current_user, params) do
      render(conn, "profile.json", profile: profile)
    end
  end

  operation(:show_current_profile,
    summary: "Show current profile",
    description: "Api to show current profile",
    operation_id: "show_current_profile",
    responses: [
      ok: {"OK", "application/json", ProfileSchema.Profile},
      unprocessable_entity: {"Unprocessable Entity", "application/json", Error},
      unauthorized: {"Unauthorized", "application/json", Error}
    ]
  )

  def show_current_profile(conn, _params) do
    current_user = conn.assigns[:current_user]

    render(conn, "current_profile.json", user: current_user)
  end
end
