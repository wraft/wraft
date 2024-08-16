defmodule WraftDoc.Kaffy.Extension do
  @moduledoc false

  def stylesheets(_conn) do
    [
      {:safe, ~s(<link rel="stylesheet" href="/kaffy/style.css" />)}
    ]
  end
end
