defmodule WraftDocWeb.AdminNext.FeatureFlagLive do
  @moduledoc """
  Admin LiveView for organisation-scoped feature flags.

  Surfaces every feature declared in `WraftDoc.FeatureFlags.available_features/0`:

  - **Global gates** (top section) — flip the FunWithFlags boolean gate, which
    enables the flag for every actor that does not have its own actor gate set.
  - **Org × Feature matrix** (bottom section) — toggles the actor gate per
    organisation. Actor gates take precedence over the global gate, so an
    explicit per-org disable overrides a global enable.

  The page is intentionally bespoke (not a Backpex `LiveResource`) because the
  feature set is a fixed enum, not a CRUD table.
  """
  use Phoenix.LiveView

  import Ecto.Query, only: [from: 2]
  import WraftDocWeb.AdminNext.UI

  alias WraftDoc.Enterprise.Organisation
  alias WraftDoc.FeatureFlags
  alias WraftDoc.Repo

  @org_page_size 25

  @feature_meta %{
    ai_features: %{
      label: "AI Features",
      description: "AI-assisted document drafting, summarisation, and analysis."
    },
    repository: %{
      label: "Repository",
      description: "Versioned document repository with branching and history."
    },
    document_extraction: %{
      label: "Document Extraction",
      description: "Structured data extraction from uploaded documents."
    }
  }

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Feature Flags")
     |> assign(:features, FeatureFlags.available_features())
     |> assign(:search, "")
     |> assign(:org_page_size, @org_page_size)
     |> load_data()}
  end

  @impl true
  def handle_event("toggle_global", %{"feature" => feature}, socket) do
    case parse_feature(feature) do
      {:ok, feature} ->
        currently_on? = FeatureFlags.enabled_globally?(feature)

        result =
          if currently_on?,
            do: FeatureFlags.disable_globally(feature),
            else: FeatureFlags.enable_globally(feature)

        {:noreply,
         socket
         |> put_toggle_flash(result, feature, !currently_on?, scope: :global)
         |> load_data()}

      :error ->
        {:noreply, put_flash(socket, :error, "Unknown feature: #{inspect(feature)}")}
    end
  end

  def handle_event("toggle_org", %{"feature" => feature, "org" => org_id}, socket) do
    with {:ok, feature} <- parse_feature(feature),
         %{} = org <- Enum.find(socket.assigns.orgs, &(&1.id == org_id)) || :not_found do
      currently_on? = FeatureFlags.enabled?(feature, org)

      result =
        if currently_on?,
          do: FeatureFlags.disable(feature, org),
          else: FeatureFlags.enable(feature, org)

      {:noreply,
       socket
       |> put_toggle_flash(result, feature, !currently_on?, scope: {:org, org.name})
       |> load_data()}
    else
      :error ->
        {:noreply, put_flash(socket, :error, "Unknown feature: #{inspect(feature)}")}

      :not_found ->
        {:noreply, put_flash(socket, :error, "Organisation not found in current view.")}
    end
  end

  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, socket |> assign(:search, q) |> load_data()}
  end

  def handle_event("clear_search", _params, socket) do
    {:noreply, socket |> assign(:search, "") |> load_data()}
  end

  # ---------------------------------------------------------------------------
  # Data loading
  # ---------------------------------------------------------------------------

  defp load_data(socket) do
    search = socket.assigns.search
    features = socket.assigns.features

    orgs = list_orgs(search)
    org_state = build_org_state(orgs, features)
    global_state = build_global_state(features, orgs)

    socket
    |> assign(:orgs, orgs)
    |> assign(:org_state, org_state)
    |> assign(:global_state, global_state)
  end

  # Returns full %Organisation{} structs (not maps) so the FunWithFlags actor
  # protocol dispatches to `defimpl ..., for: WraftDoc.Enterprise.Organisation`.
  # A bare map would hit the `for: Map` impl in waiting_list.ex, whose
  # email-first clause yields a different actor key than the write path.
  defp list_orgs(search) do
    query =
      from(o in Organisation,
        order_by: [asc: o.name],
        limit: ^@org_page_size
      )

    query
    |> apply_search(search)
    |> Repo.all()
  end

  defp apply_search(query, ""), do: query

  defp apply_search(query, search) do
    like = "%#{search}%"
    from(o in query, where: ilike(o.name, ^like) or ilike(o.email, ^like))
  end

  # Map of {org_id, feature} => boolean
  defp build_org_state(orgs, features) do
    for org <- orgs, feature <- features, into: %{} do
      {{org.id, feature}, FeatureFlags.enabled?(feature, org)}
    end
  end

  # Map of feature => %{enabled: boolean, enabled_org_count: integer}
  defp build_global_state(features, orgs) do
    for feature <- features, into: %{} do
      {feature,
       %{
         enabled: FeatureFlags.enabled_globally?(feature),
         enabled_org_count: Enum.count(orgs, &FeatureFlags.enabled?(feature, &1))
       }}
    end
  end

  # ---------------------------------------------------------------------------
  # Flash helpers
  # ---------------------------------------------------------------------------

  defp put_toggle_flash(socket, {:ok, _}, feature, now_on?, scope: :global) do
    verb = if now_on?, do: "enabled", else: "disabled"
    put_flash(socket, :info, "Globally #{verb} #{feature_label(feature)}.")
  end

  defp put_toggle_flash(socket, {:ok, _}, feature, now_on?, scope: {:org, org_name}) do
    verb = if now_on?, do: "Enabled", else: "Disabled"
    put_flash(socket, :info, "#{verb} #{feature_label(feature)} for #{org_name}.")
  end

  defp put_toggle_flash(socket, {:error, reason}, feature, _now_on?, _scope) do
    put_flash(socket, :error, "Failed to update #{feature_label(feature)}: #{inspect(reason)}")
  end

  # Resolve a client-supplied feature string to its atom, but only if it's in
  # `FeatureFlags.available_features/0`. This guards both against unknown atoms
  # (which would otherwise raise `ArgumentError` and crash the LiveView) and
  # against unrelated atoms that happen to exist in the BEAM.
  defp parse_feature(feature_string) when is_binary(feature_string) do
    feature = String.to_existing_atom(feature_string)
    if feature in FeatureFlags.available_features(), do: {:ok, feature}, else: :error
  rescue
    ArgumentError -> :error
  end

  defp feature_label(feature) do
    Map.get(@feature_meta, feature, %{})[:label] || Phoenix.Naming.humanize(feature)
  end

  defp feature_description(feature) do
    Map.get(@feature_meta, feature, %{})[:description] || ""
  end

  # ---------------------------------------------------------------------------
  # Render
  # ---------------------------------------------------------------------------

  @impl true
  def render(assigns) do
    ~H"""
    <WraftDocWeb.AdminNext.Layouts.app {assigns}>
      <div class="space-y-6">
        <.page_header
          title="Feature Flags"
          description="Control which workspaces see beta features. Global gates enable a feature for every organisation unless that organisation has an explicit override."
        >
          <:eyebrow>Automation & Integrations</:eyebrow>
          <:actions>
            <.button variant="ghost" icon="hero-arrow-top-right-on-square" href="/flags">
              FunWithFlags UI
            </.button>
          </:actions>
        </.page_header>

        <%!-- Global feature toggles --%>
        <section class="grid grid-cols-1 gap-4 md:grid-cols-3">
          <.card :for={feature <- @features} title={feature_label(feature)} caption={feature_description(feature)}>
            <:header_actions>
              <.badge variant={if @global_state[feature].enabled, do: "success", else: "neutral"}>
                {if @global_state[feature].enabled, do: "Globally on", else: "Globally off"}
              </.badge>
            </:header_actions>

            <div class="flex items-center justify-between gap-3">
              <div class="min-w-0 text-xs text-base-content/60">
                <p class="font-mono">{feature}</p>
                <p class="mt-1">
                  Enabled for
                  <span class="font-medium text-base-content">
                    {@global_state[feature].enabled_org_count}
                  </span>
                  of {length(@orgs)} listed org(s)
                </p>
              </div>

              <.toggle
                checked={@global_state[feature].enabled}
                event="toggle_global"
                feature={feature}
              />
            </div>
          </.card>
        </section>

        <%!-- Per-org matrix --%>
        <.card title="Organisations" caption="Toggle a feature for a specific workspace. Actor gates override the global gate.">
          <:header_actions>
            <form phx-change="search" phx-submit="search" class="flex items-center gap-2">
              <input
                type="search"
                name="q"
                value={@search}
                placeholder="Search organisations…"
                class="input input-bordered input-sm w-56"
                autocomplete="off"
              />
              <.button :if={@search != ""} variant="ghost" size="sm" phx-click="clear_search">
                Clear
              </.button>
            </form>
          </:header_actions>

          <%= if @orgs == [] do %>
            <.empty_state
              icon="hero-building-office-2"
              title="No organisations match"
              description={if @search == "", do: "No organisations exist yet.", else: "Try a different search term."}
            />
          <% else %>
            <.data_table>
              <:col label="Organisation" />
              <:col :for={feature <- @features} label={feature_label(feature)} align="center" />
              <:row>
                <tr :for={org <- @orgs}>
                  <td class="min-w-0">
                    <p class="font-medium text-base-content truncate">{org.name}</p>
                    <p class="mt-0.5 font-mono text-xs text-base-content/55 truncate">{org.email}</p>
                  </td>
                  <td :for={feature <- @features} class="text-center">
                    <.toggle
                      checked={@org_state[{org.id, feature}]}
                      event="toggle_org"
                      feature={feature}
                      org={org.id}
                    />
                  </td>
                </tr>
              </:row>
            </.data_table>

            <p :if={length(@orgs) >= @org_page_size} class="mt-3 ds-caption">
              Showing first {@org_page_size} matches. Refine your search to find a specific org.
            </p>
          <% end %>
        </.card>
      </div>
    </WraftDocWeb.AdminNext.Layouts.app>
    """
  end

  defp toggle(assigns) do
    assigns = assign_new(assigns, :org, fn -> nil end)

    ~H"""
    <button
      type="button"
      role="switch"
      aria-checked={to_string(@checked)}
      phx-click={@event}
      phx-value-feature={@feature}
      phx-value-org={@org}
      class={[
        "relative inline-flex h-5 w-9 items-center rounded-full transition-colors",
        if(@checked, do: "bg-success", else: "bg-base-300")
      ]}
    >
      <span class={[
        "inline-block size-4 transform rounded-full bg-white shadow transition-transform",
        if(@checked, do: "translate-x-4", else: "translate-x-0.5")
      ]} />
    </button>
    """
  end
end
