defmodule WraftDocWeb.SessionController do
  @moduledoc """
  Session controller module handles session for admin
  """
  use WraftDocWeb, :controller

  alias WraftDoc.InternalUsers
  alias WraftDoc.InternalUsers.InternalUser
  alias WraftDoc.RateLimiter

  @signin_window_ms :timer.minutes(15)
  @signin_max_attempts 5

  def new(conn, _params) do
    changeset = InternalUsers.change_internal_user()

    conn
    |> put_layout(false)
    |> render(:new, changeset: changeset)
  end

  def create(conn, %{"session" => params}) do
    with :ok <- check_signin_rate(conn, params["email"]),
         %InternalUser{is_deactivated: false} = user <- get_user(params["email"]),
         true <- Bcrypt.verify_pass(params["password"], user.encrypted_password) do
      conn
      # Renew the session id at privilege elevation so a pre-login cookie
      # cannot be fixated into an authenticated one.
      |> configure_session(renew: true)
      |> put_admin_session(user)
      |> put_flash(:info, "Signed in successfully.")
      |> redirect(to: "/admin")
    else
      :rate_limited ->
        conn
        |> put_flash(:error, "Too many sign-in attempts. Please try again later.")
        |> redirect(to: session_path(conn, :new))

      %InternalUser{is_deactivated: true} ->
        # A correct password for a deactivated account is not a failed
        # attempt — don't count it toward the lockout.
        conn
        |> put_flash(:info, "Your account has been deactivated, please contact support.")
        |> redirect(to: session_path(conn, :new))

      _ ->
        record_failed_attempt(conn, params["email"])

        conn
        |> put_flash(:error, "Please provide the correct login credentials to login.")
        |> redirect(to: session_path(conn, :new))
    end
  end

  @doc """
  Delete a session.
  """
  def delete(conn, _) do
    conn
    |> delete_session(:admin_id)
    |> delete_session(:admin_iat)
    |> delete_session(:admin_epoch)
    # New session id on logout; keeps the flash (a full drop would discard it).
    |> configure_session(renew: true)
    |> put_flash(:info, "Signed out successfully.")
    |> redirect(to: session_path(conn, :new))
  end

  defp put_admin_session(conn, user) do
    Enum.reduce(InternalUsers.admin_session_attrs(user), conn, fn {key, value}, conn ->
      put_session(conn, key, value)
    end)
  end

  defp get_user(email) do
    case InternalUsers.get_by_email(email) do
      nil ->
        # Burn a hash on unknown emails so response timing does not reveal
        # whether an address exists.
        Bcrypt.no_user_verify()
        nil

      user ->
        user
    end
  end

  # Read-only check at the gate so a successful sign-in does not consume
  # the budget; only failed attempts increment it (see
  # record_failed_attempt/2). Read-then-increment is fine here — the worst
  # case is one extra attempt slipping through under concurrency, far below
  # the security threshold.
  defp check_signin_rate(conn, email) do
    if RateLimiter.get(signin_key(conn, email), @signin_window_ms) >= @signin_max_attempts do
      :rate_limited
    else
      :ok
    end
  end

  defp record_failed_attempt(conn, email) do
    RateLimiter.inc(signin_key(conn, email), @signin_window_ms)
  end

  defp signin_key(conn, email), do: "admin-signin:#{remote_ip(conn)}:#{email}"

  defp remote_ip(conn), do: conn.remote_ip |> :inet.ntoa() |> to_string()
end
