defmodule WraftDocWeb.AdminNext.Layouts do
  use Phoenix.Component

  alias Backpex.Router

  embed_templates "layouts/*"

  @doc """
  Computes breadcrumb segments from the current URL. Returns a list of
  `{label, path_or_nil}` tuples. The last entry has `nil` path (current page).
  """
  def breadcrumbs(nil), do: [{"Admin", "/admin"}]

  def breadcrumbs(url) do
    %{path: path} = URI.parse(url)
    segments = String.split(path || "/admin", "/", trim: true)

    case segments do
      ["admin"] ->
        [{"Admin", nil}]

      ["admin", resource] ->
        section = section_for(resource)

        [{"Admin", "/admin"}]
        |> maybe_add_section(section)
        |> Kernel.++([{humanize(resource), nil}])

      ["admin", resource | rest] ->
        section = section_for(resource)
        leaf = leaf_label(resource, List.last(rest))

        [{"Admin", "/admin"}]
        |> maybe_add_section(section)
        |> Kernel.++([{humanize(resource), "/admin/#{resource}"}, {leaf, nil}])

      _ ->
        [{"Admin", "/admin"}]
    end
  end

  # Pretty leaf for nested routes like /admin/audit-logs/<uuid> — show a
  # readable label per resource, otherwise fall back to humanizing the slug.
  defp leaf_label("audit-logs", _id), do: "Event detail"
  defp leaf_label("queue-monitoring", _id), do: "Job detail"
  defp leaf_label(_resource, slug), do: humanize(slug)

  defp maybe_add_section(crumbs, nil), do: crumbs
  defp maybe_add_section(crumbs, section), do: crumbs ++ [{section, nil}]

  defp section_for(resource) when resource in ["plans", "enterprise-plans", "coupons"],
    do: "Subscription & Billing"

  defp section_for(resource)
       when resource in ["users", "user-roles", "internal-users", "organisations"],
       do: "Workspace"

  defp section_for(resource)
       when resource in ["template-assets", "frames", "field-types"],
       do: "Contract Platform"

  defp section_for(resource) when resource in ["waiting-list"], do: "Marketing"

  defp section_for(resource)
       when resource in ["admin-webhooks", "feature-flags", "queue-monitoring"],
       do: "Automation & Integrations"

  defp section_for(resource) when resource in ["audit-logs"], do: "Security"
  defp section_for(_), do: nil

  defp humanize(slug) do
    slug
    |> String.replace("-", " ")
    |> String.split(" ")
    |> Enum.map_join(" ", &String.capitalize/1)
  end

  @doc """
  Sidebar section heading + child links. Always expanded — sections are
  not collapsible so the full navigation stays visible.
  """
  attr :icon, :string, default: nil
  attr :label, :string, required: true
  attr :open, :boolean, default: true, doc: "Kept for backwards compatibility; ignored."
  slot :inner_block, required: true

  def nav_section(assigns) do
    ~H"""
    <li class="mt-3 list-none">
      <p class="text-zinc-500 mx-2 flex items-center gap-2.5 rounded-md px-3 py-1.5 text-[10px] font-semibold uppercase tracking-wider">
        <%!-- Spacer matches the icon column in nav_link so section labels
             align horizontally with item labels. --%>
        <span>{@label}</span>
      </p>
      <ul class="mt-0.5 ml-0 space-y-px">
        {render_slot(@inner_block)}
      </ul>
    </li>
    """
  end

  @doc """
  Sidebar nav link — icon + label. Dark theme.
  """
  attr :current_url, :string, default: nil
  attr :path, :string, required: true
  attr :icon, :string, required: true
  attr :label, :string, required: true

  def nav_link(assigns) do
    assigns = assign(assigns, :active, active?(assigns.current_url, assigns.path))

    ~H"""
    <li class="px-2">
      <.link
        navigate={@path}
        class={[
          "group/link flex items-center gap-2.5 rounded-md px-2 py-1.5 text-sm transition",
          @active && "bg-white/10 text-white",
          !@active && "text-zinc-400 hover:bg-white/5 hover:text-zinc-100"
        ]}
      >
        <span class="grid size-6 shrink-0 place-items-center">
          <Backpex.HTML.CoreComponents.icon
            name={@icon}
            class={[
              "size-4 transition",
              @active,
              !@active && "text-zinc-500 group-hover/link:text-zinc-300"
            ]}
          />
        </span>
        <span class="flex-1 truncate">{@label}</span>
      </.link>
    </li>
    """
  end

  defp active?(nil, _), do: false

  defp active?(current, "/admin") do
    %{path: path} = URI.parse(current)
    path in [nil, "/admin", "/admin/"]
  end

  defp active?(current, path), do: Router.active?(current, path)

  @doc """
  Renders the admin's initials in a small colored tile — used in the
  sidebar footer.
  """
  attr :email, :string, required: true

  def avatar(assigns) do
    assigns = assign(assigns, :initials, initials(assigns.email))

    ~H"""
    <div class="bg-primary/20 text-primary grid size-6 shrink-0 place-items-center rounded-md text-[10px] font-semibold">
      {@initials}
    </div>
    """
  end

  defp initials(nil), do: "?"

  defp initials(email) when is_binary(email) do
    email
    |> String.split("@")
    |> List.first()
    |> String.split([".", "-", "_"])
    |> Enum.take(2)
    |> Enum.map_join("", &String.first(&1))
    |> String.upcase()
  end
end
