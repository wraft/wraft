defmodule WraftDocWeb.Guardian do
  @moduledoc """
    The main Guardian module. Responsible for selecting the subject
    for token geration and retrieving subject from the token.
  """
  use Guardian, otp_app: :wraft_doc

  def subject_for_token(%{email: email}, _claims) do
    # You can use any value for the subject of your token but
    # it should be useful in retrieving the resource later, see
    # how it being used on `resource_from_claims/1` function.
    # A unique `id` is a good subject, a non-unique email address
    # is a poor subject.
    sub = to_string(email)
    {:ok, sub}
  end

  def subject_for_token(_, _) do
    {:error, :reason_for_error}
  end

  def resource_from_claims(%{"sub" => email}) do
    # Here we'll look up our resource from the claims, the subject can be
    # found in the `"sub"` key. In `above subject_for_token/2` we returned
    # the resource id so here we'll rely on that to look it up.
    {:ok, email}
  end

  def resource_from_claims(_claims) do
    {:error, :reason_for_error}
  end

  def after_encode_and_sign(resource, claims, token, _options) do
    with {:ok, _} <- Guardian.DB.after_encode_and_sign(resource, claims["typ"], claims, token) do
      {:ok, token}
    end
  end

  def on_verify(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_verify(claims, token) do
      {:ok, claims}
    end
  end

  def on_refresh({old_token, old_claims}, {new_token, new_claims}, _options) do
    with {:ok, _, _} <- Guardian.DB.on_refresh({old_token, old_claims}, {new_token, new_claims}) do
      {:ok, {old_token, old_claims}, {new_token, new_claims}}
    end
  end

  def on_revoke(claims, token, _options) do
    with {:ok, _} <- Guardian.DB.on_revoke(claims, token) do
      {:ok, claims}
    end
  end

  @doc """
    Generate tokens
  """
  @spec generate_tokens(User.t(), Ecto.UUID.t()) :: [
          access_token: Guardian.Token.token(),
          refresh_token: Guardian.Token.token()
        ]
  def generate_tokens(user, org_id) do
    # Generate access token
    {:ok, access_token, _} =
      encode_and_sign(user, %{organisation_id: org_id},
        token_type: "access",
        ttl: {2, :hour}
      )

    # Generate refresh token
    {:ok, refresh_token, _} =
      encode_and_sign(user, %{organisation_id: org_id},
        token_type: "refresh",
        ttl: {2, :day}
      )

    [access_token: access_token, refresh_token: refresh_token]
  end
end
