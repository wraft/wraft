defmodule WraftDoc.Factory do
  use ExMachina.Ecto, repo: WraftDoc.Repo
  alias WraftDoc.{Account.User, Enterprise.Organisation, Account.Role, Account.Profile}

  def user_factory do
    %User{
      name: sequence(:name, &"wrafts user-#{&1}"),
      email: sequence(:email, &"wraftuser-#{&1}@gmail.com"),
      password: "encrypt",
      encrypted_password: Bcrypt.hash_pwd_salt("encrypt"),
      organisation: build(:organisation),
      role: build(:role)
    }
  end

  def organisation_factory do
    %Organisation{name: sequence(:name, &"organisation-#{&1}")}
  end

  def role_factory do
    %Role{name: "user"}
  end

  def profile_factory do
    %Profile{
      name: sequence(:name, &"name-#{&1}"),
      dob: GoodTimes.years_ago(27),
      gender: "male"
    }
  end
end
