defmodule WraftDocWeb.Mailer.Email do
  import Bamboo.Email

  def invite_email(org_name, user_name, email, token) do
    base_email()
    |> to(email)
    |> subject("Invitation to join #{org_name} in WraftDocs")
    |> html_body(
      "Hi, #{user_name} has invited you to join #{org_name} in WraftDocs. \n
    Click <a href=#{WraftDocWeb.Endpoint.url()}/users/signup?token=#{token}>here</a> below to join."
    )
  end

  defp base_email do
    new_email()
    |> from({"WraftDoc", "admin@wraftdocs.com"})
  end
end
