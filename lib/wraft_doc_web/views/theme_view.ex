defmodule WraftDocWeb.Api.V1.ThemeView do
  use WraftDocWeb, :view

  def render("create.json", %{theme: theme}) do
    %{
      id: theme.uuid,
      name: theme.name,
      font: theme.font,
      typescale: theme.typescale,
      file: theme |> generate_url()
    }
  end

  defp generate_url(%{file: file} = theme) do
    WraftDocWeb.ThemeUploader.url({file, theme})
  end
end
