defmodule WraftDocWeb.Api.V1.ThemeView do
  use WraftDocWeb, :view
  alias __MODULE__
  alias WraftDocWeb.Api.V1.UserView

  def render("create.json", %{theme: theme}) do
    %{
      id: theme.uuid,
      name: theme.name,
      font: theme.font,
      typescale: theme.typescale,
      file: theme |> generate_url(),
      updated_at: theme.updated_at,
      inserted_at: theme.inserted_at
    }
  end

  def render("index.json", %{themes: themes}) do
    render_many(themes, ThemeView, "create.json", as: :theme)
  end

  def render("show.json", %{theme: theme}) do
    %{
      theme: render_one(theme, ThemeView, "create.json", as: :theme),
      creator: render_one(theme.creator, UserView, "user.json", as: :user)
    }
  end

  defp generate_url(%{file: file} = theme) do
    WraftDocWeb.ThemeUploader.url({file, theme})
  end
end
