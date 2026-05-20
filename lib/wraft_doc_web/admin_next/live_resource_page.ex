defmodule WraftDocWeb.AdminNext.LiveResourcePage do
  @moduledoc """
  Shared page-header decoration for Backpex `LiveResource` modules.

  Adds:

  - A richer **`:index, :page_title`** slot: title + subtitle (from
    `subtitle/0`) + Backpex's default action buttons aligned to the right
    so they sit beside the title instead of below it.
  - A consistent left/right alignment, generous spacing, and a divider
    below — closer to the enterprise-admin mockup.

  ## Usage

      use Backpex.LiveResource, ...

      use WraftDocWeb.AdminNext.LiveResourcePage,
        subtitle: "Manage users and their organisation memberships."

  Each LiveResource may also override `subtitle/0` directly if the text
  needs to be computed.
  """

  defmacro __using__(opts) do
    subtitle = Keyword.get(opts, :subtitle, nil)

    quote do
      @resource_subtitle unquote(subtitle)

      @doc """
      Descriptive subtitle rendered below the page title on the index/show
      page. Override to compute dynamically.
      """
      def subtitle, do: @resource_subtitle

      @doc """
      Extra action buttons rendered alongside Backpex's default
      `resource_buttons` in the page header. Override to add custom
      CTAs (e.g. an Import link). Default: empty.
      """
      def extra_actions(var!(assigns)) do
        _ = var!(assigns)
        ~H""
      end

      defoverridable subtitle: 0, extra_actions: 1

      @impl Backpex.LiveResource
      def render_resource_slot(var!(assigns), :index, :page_title) do
        WraftDocWeb.AdminNext.LiveResourcePage.index_page_title(
          var!(assigns),
          plural_name(),
          subtitle(),
          extra_actions(var!(assigns))
        )
      end

      @impl Backpex.LiveResource
      def render_resource_slot(var!(assigns), :show, :page_title) do
        WraftDocWeb.AdminNext.LiveResourcePage.show_page_title(
          var!(assigns),
          singular_name(),
          subtitle()
        )
      end

      # Buttons are rendered inside the :page_title slot above, so suppress
      # Backpex's default :actions row to avoid duplicate buttons.
      @impl Backpex.LiveResource
      def render_resource_slot(var!(assigns), :index, :actions), do: ~H""

      defoverridable render_resource_slot: 3
    end
  end

  use Phoenix.Component

  import WraftDocWeb.AdminNext.UI

  @doc """
  Renders the rich page title for the index view: large title + subtitle
  on the left, optional `extra_actions` followed by Backpex's
  `resource_buttons` aligned to the right.
  """
  def index_page_title(assigns, title, subtitle, extra_actions \\ nil) do
    assigns =
      assigns
      |> assign(:title, title)
      |> assign(:subtitle, subtitle)
      |> assign(:extra_actions, extra_actions)

    ~H"""
    <.page_header title={@title} description={@subtitle} class="mb-4">
      <:actions>
        {@extra_actions}
        <Backpex.HTML.Resource.resource_buttons {assigns} />
      </:actions>
    </.page_header>
    """
  end

  @doc """
  Renders the rich page title for the show view.
  """
  def show_page_title(assigns, _singular_name, subtitle) do
    assigns = assign(assigns, :subtitle, subtitle)

    ~H"""
    <.page_header title={@page_title} description={@subtitle} class="mb-4">
      <:actions>
        <%= for {key, action} <- Backpex.HTML.Resource.filter_item_actions(@item_actions, :show),
                @live_resource.can?(assigns, key, @item) do %>
          <%= if Backpex.ItemAction.has_link?(action) do %>
            <.link
              id={"item-action-#{key}"}
              navigate={action.module.link(assigns, @item)}
              class="ds-btn ds-btn-neutral ds-btn-sm"
            >
              {action.module.icon(assigns, @item)}
              <span>{action.module.label(assigns, @item)}</span>
            </.link>
          <% else %>
            <button
              id={"item-action-#{key}"}
              type="button"
              phx-click="item-action"
              phx-value-action-key={key}
              class="ds-btn ds-btn-neutral ds-btn-sm"
            >
              {action.module.icon(assigns, @item)}
              <span>{action.module.label(assigns, @item)}</span>
            </button>
          <% end %>
        <% end %>
      </:actions>
    </.page_header>
    """
  end
end
