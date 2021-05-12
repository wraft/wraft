defmodule WraftDocWeb.FallbackController do
  @moduledoc """
  Translates controller action results into valid `Plug.Conn` responses.

  See `Phoenix.Controller.action_fallback/1` for more details.
  """
  use WraftDocWeb, :controller

  def call(conn, {:error, %Ecto.Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(WraftDocWeb.ChangesetView, "error.json", changeset: changeset)
  end

  def call(conn, {:error, :invalid}) do
    body =
      Jason.encode!(%{errors: "Your email-password combination doesn't match. Please try again.!"})

    conn |> put_resp_content_type("application/json") |> send_resp(404, body)
  end

  def call(conn, {:error, :no_data}) do
    body = Jason.encode!(%{errors: "Please provide all necessary datas to login.!"})
    conn |> put_resp_content_type("application/json") |> send_resp(400, body)
  end

  def call(conn, {:error, :invalid_email}) do
    body = Jason.encode!(%{errors: "No user with this email.!"})

    conn |> put_resp_content_type("application/json") |> send_resp(404, body)
  end

  def call(conn, {:error, :fake}) do
    body = Jason.encode!(%{errors: "You are not authorized for this action.!"})

    conn |> put_resp_content_type("application/json") |> send_resp(401, body)
  end

  def call(conn, {:error, :invalid_password}) do
    body = Jason.encode!(%{errors: "You have entered a wrong password.!"})
    conn |> put_resp_content_type("application/json") |> send_resp(400, body)
  end

  def call(conn, {:error, :same_password}) do
    body =
      Jason.encode!(%{
        errors: "Please enter a password that does not match with your current one.!"
      })

    conn |> put_resp_content_type("application/json") |> send_resp(400, body)
  end

  def call(conn, {:error, :no_permission}) do
    body = Jason.encode!(%{errors: "You are not authorized for this action.!"})
    conn |> put_resp_content_type("application/json") |> send_resp(400, body)
  end

  def call(conn, {:error, :expired}) do
    body = Jason.encode!(%{errors: "Expired.!"})
    conn |> put_resp_content_type("application/json") |> send_resp(400, body)
  end

  def call(conn, {:error, :already_member}) do
    body = Poison.encode!(%{errors: "User with this email exists.!"})
    conn |> put_resp_content_type("application/json") |> send_resp(422, body)
  end

  def call(conn, {:error, :version_not_found}) do
    body = Poison.encode!(%{errors: "Version does not exist.!"})
    conn |> put_resp_content_type("application/json") |> send_resp(422, body)
  end

  def call(conn, {:error, :wrong_flow}) do
    body = Poison.encode!(%{errors: "This instance follow a different flow.!"})
    conn |> put_resp_content_type("application/json") |> send_resp(422, body)
  end

  def call(conn, {:error, %Razorpay.Error{description: description}}) do
    body = Jason.encode!(%{errors: description})
    conn |> put_resp_content_type("application/json") |> send_resp(422, body)
  end

  def call(conn, {:error, :wrong_amount}) do
    body = Jason.encode!(%{errors: "No plan with paid amount..!!"})
    conn |> put_resp_content_type("application/json") |> send_resp(422, body)
  end

  def call(conn, {:error, :cant_update}) do
    body = Jason.encode!(%{errors: "The instance is not avaliable to edit..!!"})
    conn |> put_resp_content_type("application/json") |> send_resp(422, body)
  end

  def call(conn, {:error, :invalid_id}) do
    body = Jason.encode!(%{errors: "The id does not exist..!"})
    conn |> put_resp_content_type("application/json") |> send_resp(400, body)
  end

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(WraftDocWeb.ErrorView, :"404")
  end
end
