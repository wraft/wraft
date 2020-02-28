defmodule WraftDoc.Factory do
  # with Ecto
  use ExMachina.Ecto, repo: WraftDoc.Repo
  alias WraftDoc.{Account, Account.User, Account.Profile}

  def user_factory do
    role = Account.get_role()
    name = sequence(:name, &"user-#{&1}")

    %User{
      name: name,
      email: sequence(:email, &"email#{&1}@xyz.com"),
      encrypted_password: Bcrypt.hash_pwd_salt("encrypt"),
      email_verify: true,
      role_id: role.id
    }

    %Profile{
      name: name
    }
  end

  def layout_factory do
    # title = sequence(:title, &"Use ExMachina! (Part #{&1})")
  end
end
