defmodule WraftDoc.Account.Profile do
  @moduledoc """
    This is the Profile model
  """
  use WraftDoc.Schema
  use Waffle.Ecto.Schema

  schema "basic_profile" do
    field(:name, :string)
    field(:profile_pic, WraftDocWeb.PropicUploader.Type)
    field(:dob, :date)
    field(:gender, :string)
    belongs_to(:user, WraftDoc.Account.User)
    belongs_to(:country, WraftDoc.Account.Country)

    timestamps()
  end

  def changeset(profile, attrs \\ %{}) do
    profile
    |> cast(attrs, [
      :name,
      :dob,
      :gender,
      :user_id
    ])
    |> cast_attachments(attrs, [:profile_pic])
    |> validate_required([:name, :user_id])
    |> validate_format(:name, ~r/^[A-z ]+$/)
    |> validate_length(:name, min: 2)

    # |> validate_dob
  end

  # @deprecated "Not used anymore"
  # defp validate_dob(current_changeset) do
  #   if Map.has_key?(current_changeset.changes, :dob) do
  #     dob = current_changeset.changes.dob
  #     # {:ok, dob} = Timex.parse(current_changeset.changes.dob, "{YYYY}-{M}-{D}")
  #     age = Timex.diff(Timex.now(), dob, :years)

  #     if age > 15 do
  #       put_change(current_changeset, :dob, dob)
  #     else
  #       add_error(current_changeset, :dob, "You are not old enough to use or services, sorry.!")
  #     end
  #   else
  #     current_changeset
  #   end
  # end
end
