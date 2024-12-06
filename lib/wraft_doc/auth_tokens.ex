defmodule WraftDoc.AuthTokens do
  @moduledoc """
    Handles the creation, verification, and deletion of authentication tokens.
    This includes tokens for password reset and email verification.
  """
  import Ecto
  import Ecto.Query

  alias WraftDoc.Account
  alias WraftDoc.Account.User
  alias WraftDoc.AuthTokens.AuthToken
  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.Repo
  alias WraftDoc.Workers.EmailWorker
  alias WraftDocWeb.Endpoint

  @base_googe_auth_url "https://www.googleapis.com/oauth2/v3/tokeninfo?id_token="

  @doc """
  Insert auth token without expiry date.
  """
  @spec insert_auth_token!(User.t() | any(), map) :: AuthToken.t()
  def insert_auth_token!(%User{} = user, params) do
    user
    |> build_assoc(:auth_tokens)
    |> AuthToken.changeset(params)
    |> Repo.insert!()
  end

  def insert_auth_token!(_, _), do: raise("Unexpected arguments passed.")

  @spec insert_auth_token!(map) :: AuthToken.t()
  def insert_auth_token!(params) do
    %AuthToken{}
    |> AuthToken.changeset(params)
    |> Repo.insert()
  end

  @doc """
  Generate auth token for password reset for the user with the given email ID
  and insert it to auth_tokens table.
  """
  def create_password_token(%{"email" => email}) do
    email = String.downcase(email)

    case Account.get_user_by_email(email) do
      %User{} = current_user ->
        delete_auth_token(current_user.id, "password_verify")
        token = WraftDoc.create_phx_token("reset", current_user.email)
        params = %{value: token, token_type: "password_verify"}

        current_user |> insert_auth_token!(params) |> Repo.preload(:user)

      nil ->
        {:error, :invalid_email}
    end
  end

  def create_password_token(_), do: {:error, :invalid_email}

  @doc """
  Deletes an authtoken.
  Raises if anything goes wrong.
  """
  @spec delete_auth_token!(AuthToken.t() | String.t()) :: AuthToken.t()
  def delete_auth_token!(auth_token), do: Repo.delete!(auth_token)

  @doc """
  Finds the given auth token and deletes it.
  If the auth token is non-existent, returns error tuple.
  """
  @spec delete_auth_token(binary()) :: {:ok, %AuthToken{}} | {:error, :invalid}
  def delete_auth_token(token_value) when is_binary(token_value) do
    AuthToken
    |> Repo.get_by(value: token_value)
    |> case do
      %AuthToken{} = token -> Repo.delete(token)
      nil -> {:error, :invalid}
    end
  end

  @doc """
  Deletes all tokens of given type associated with the user_id.
  """
  @spec delete_auth_token(Ecto.UUID.t(), String.t()) :: {integer(), [AuthToken.t()]}
  def delete_auth_token(user_id, type) do
    query =
      from(
        a in AuthToken,
        where: a.user_id == ^user_id,
        where: a.token_type == ^type
      )

    Repo.delete_all(query)
  end

  @doc """
   Create email verification token and send email
  """
  @spec create_token_and_send_email(binary()) :: {:ok, Oban.Job.t()} | {:error, atom()}
  def create_token_and_send_email(email) do
    email
    |> create_email_verification_token()
    |> case do
      {:ok, %AuthToken{} = auth_token} ->
        Account.send_email(email, auth_token)

      {:error, :invalid_email} ->
        {:error, :invalid_email}
    end
  end

  @doc """
  Generate and insert auth_token for email verification
  """
  @spec create_email_verification_token(binary()) :: {:ok, AuthToken.t()} | {:error, atom()}
  def create_email_verification_token(email) do
    case Account.get_user_by_email(email) do
      %User{} = user ->
        token =
          WraftDoc.create_phx_token("email_verification", %{
            email: user.email
          })

        params = %{value: token, token_type: "email_verify"}

        auth_token = insert_auth_token!(user, params)

        {:ok, auth_token}

      nil ->
        {:error, :invalid_email}
    end
  end

  @doc """
   Create document invite token
  """
  @spec create_document_invite_token(User.t(), Ecto.UUID.t(), map()) :: {:ok, AuthToken.t()}
  def create_document_invite_token(
        user,
        state_id,
        %{"email" => email, "role" => role, "id" => document_id}
      ) do
    token =
      WraftDoc.create_phx_token("document_invite", %{
        email: email,
        role: role,
        document_id: document_id,
        state_id: state_id
      })

    params = %{value: token, token_type: "document_invite"}

    auth_token = insert_auth_token!(user, params)

    {:ok, auth_token}
  end

  @doc """
  Verify Delete Organisation Token
  """
  @spec verify_delete_token(User.t(), map()) ::
          AuthToken.t() | {:error, :fake} | {:error, :expired}
  def verify_delete_token(user, %{"code" => code}) do
    case get_auth_token("#{user.current_org_id}:#{code}", :delete_organisation, %{
           "user_id" => user.id
         }) do
      %AuthToken{} = token ->
        delete_auth_token!(token)

      _ ->
        {:error, :fake}
    end
  end

  def verify_delete_token(_, _), do: {:error, :fake}

  @doc """
  Generate Delete Organisation Token
  """
  @spec generate_delete_token_and_send_email(User.t(), Organisation.t()) :: {:ok, Oban.Job.t()}
  def generate_delete_token_and_send_email(%User{} = user, %Organisation{} = organisation) do
    params = build_params(organisation.id)

    delete_auth_token(user.id, "delete_organisation")
    insert_auth_token!(user, params)

    delete_code = params.value |> String.split(":") |> List.last()

    %{
      email: user.email,
      delete_code: delete_code,
      user_name: user.name,
      organisation_name: organisation.name
    }
    |> EmailWorker.new(queue: "mailer", tags: ["organisation_delete_code"])
    |> Oban.insert()
  end

  def generate_delete_token_and_send_email(_, _), do: {:error, :fake}

  defp build_params(organisation_id) do
    delete_code = 100_000..999_999 |> Enum.random() |> Integer.to_string()

    %{
      value: "#{organisation_id}:#{delete_code}",
      token_type: "delete_organisation",
      expiry_datetime: NaiveDateTime.add(NaiveDateTime.utc_now(), 10 * 60, :second)
    }
  end

  @doc """
  Validate the phoenix token.
  """
  @spec check_token(String.t(), atom()) :: AuthToken.t() | {:ok, any()} | {:error, atom()}
  def check_token(token, token_type) when token_type == :password_verify do
    case get_auth_token(token, token_type) do
      nil ->
        {:error, :fake}

      %AuthToken{value: token} = token_struct ->
        case phoenix_token_verify(token, "reset", max_age: 860) do
          {:ok, _} ->
            Repo.preload(token_struct, :user)

          error ->
            error
        end
    end
  end

  def check_token(token, :invite) do
    case get_auth_token(token, :invite) do
      nil ->
        {:error, :fake}

      %AuthToken{value: token} ->
        # Max age for `organisation_invite` is 10 days
        case phoenix_token_verify(token, "organisation_invite", max_age: 864_000) do
          {:ok, payload} ->
            {:ok, payload}

          {:error, :expired} ->
            {:error, :expired}

          _ ->
            {:error, :fake}
        end
    end
  end

  def check_token(token, token_type) when token_type == :email_verify do
    case get_auth_token(token, token_type) do
      nil ->
        {:error, :fake}

      %AuthToken{value: token} ->
        case phoenix_token_verify(token, "email_verification", max_age: 7200) do
          {:ok, payload} ->
            {:ok, payload}

          {:error, :expired} ->
            {:error, :expired}

          _ ->
            {:error, :fake}
        end
    end
  end

  def check_token(token, token_type) when token_type == :document_invite do
    case get_auth_token(token, token_type) do
      nil ->
        {:error, :fake}

      %AuthToken{value: token} ->
        case phoenix_token_verify(token, "document_invite", max_age: 864_000) do
          {:ok, payload} ->
            {:ok, payload}

          {:error, :expired} ->
            {:error, :expired}

          _ ->
            {:error, :fake}
        end
    end
  end

  def check_token(token, token_type) when token_type == :set_password do
    case get_auth_token(token, token_type) do
      nil ->
        {:error, :fake}

      %AuthToken{value: token} ->
        case phoenix_token_verify(token, "set_password", max_age: :infinity) do
          {:ok, payload} ->
            {:ok, payload}

          {:error, :expired} ->
            {:error, :expired}

          _ ->
            {:error, :fake}
        end
    end
  end

  @spec get_auth_token(String.t(), atom(), map()) :: AuthToken.t() | nil
  def get_auth_token(value, token_type, params \\ %{}) do
    AuthToken
    |> where([t], t.value == ^value)
    |> where([t], t.token_type == ^token_type)
    |> where(^auth_token_filter(params))
    |> where([t], ^maybe_check_expiry(token_type))
    |> Repo.one()
  end

  defp auth_token_filter(%{"user_id" => user_id} = _params),
    do: dynamic([t], t.user_id == ^user_id)

  defp auth_token_filter(_), do: true

  defp maybe_check_expiry(token_type) when token_type == :delete_organisation,
    do: dynamic([t], ^NaiveDateTime.utc_now() < t.expiry_datetime)

  defp maybe_check_expiry(_), do: true

  def phoenix_token_verify(token, secret, opts) do
    {:ok, decoded_token} = Base.url_decode64(token)

    Endpoint
    |> Phoenix.Token.verify(secret, decoded_token, opts)
    |> case do
      {:error, :invalid} ->
        {:error, :fake}

      {:error, :expired} ->
        {:error, :expired}

      {:ok, payload} ->
        {:ok, payload}
    end
  end

  # TODO add tests.
  # TODO improvise using Tesla.
  @spec google_auth_validation(String.t()) :: {:ok, %{email: String.t()}} | {:error, String.t()}
  def google_auth_validation(token) do
    (@base_googe_auth_url <> token)
    |> HTTPoison.get!()
    |> case do
      %HTTPoison.Response{status_code: 200, body: body} ->
        body = Jason.decode!(body)
        email = String.downcase(body["email"])
        {:ok, %{email: email}}

      %HTTPoison.Response{status_code: 400} ->
        {:error, :expired}

      _ ->
        {:error, :fake}
    end
  end

  @doc """
    Create set password token
  """
  @spec create_set_password_token(User.t()) :: AuthToken.t()
  def create_set_password_token(user) do
    token = WraftDoc.create_phx_token("set_password", user.email, max_age: :infinity)
    params = %{value: token, token_type: "set_password"}
    insert_auth_token!(user, params)
  end
end
