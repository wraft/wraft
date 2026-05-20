defmodule WraftDocWeb.AdminNext.FeatureFlagLiveTest do
  @moduledoc """
  Tests for the `/admin/feature-flags` admin LiveView.

  These tests deliberately exercise the *integration* between the LiveView and
  `WraftDoc.FeatureFlags`/FunWithFlags rather than re-testing the API layer.
  In particular, the per-org toggle test guards against a previous regression
  where `list_orgs/1` projected `%{id, name, email}` instead of `%Organisation{}`,
  causing the `FunWithFlags.Actor` protocol to dispatch to `for: Map` (whose
  `:email` clause is matched first), so writes and reads addressed different
  actor keys and toggles appeared not to persist.
  """
  use WraftDocWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import WraftDoc.Factory

  alias WraftDoc.FeatureFlags

  @path "/admin/feature-flags"

  setup do
    admin = insert(:internal_user)

    conn =
      Plug.Test.init_test_session(Phoenix.ConnTest.build_conn(), %{"admin_id" => admin.id})

    {:ok, conn: conn, admin: admin}
  end

  describe "mount/render" do
    test "renders a card for every available feature", %{conn: conn} do
      {:ok, _view, html} = live(conn, @path)

      for feature <- FeatureFlags.available_features() do
        assert html =~ to_string(feature)
      end

      assert html =~ "Feature Flags"
      assert html =~ "Organisations"
    end

    test "lists organisations alphabetically", %{conn: conn} do
      insert(:organisation, name: "Zeta Corp")
      insert(:organisation, name: "Alpha Inc")

      {:ok, _view, html} = live(conn, @path)

      alpha_pos = elem(:binary.match(html, "Alpha Inc"), 0)
      zeta_pos = elem(:binary.match(html, "Zeta Corp"), 0)
      assert alpha_pos < zeta_pos
    end
  end

  describe "toggle_org event" do
    # Regression test: a bare-map projection would dispatch to the wrong
    # protocol impl and this assertion would fail because FeatureFlags.enabled?/2
    # would still return false even though the write returned :ok.
    test "enabling a feature for an org persists and is visible on re-render", %{conn: conn} do
      org = insert(:organisation, name: "Test Org")
      refute FeatureFlags.enabled?(:ai_features, org)

      {:ok, view, _html} = live(conn, @path)

      view
      |> element(
        ~s|button[phx-click="toggle_org"][phx-value-feature="ai_features"][phx-value-org="#{org.id}"]|
      )
      |> render_click()

      assert FeatureFlags.enabled?(:ai_features, org)
      assert render(view) =~ ~s|aria-checked="true"|
    end

    test "toggling twice round-trips back to disabled", %{conn: conn} do
      org = insert(:organisation)

      {:ok, view, _html} = live(conn, @path)

      selector =
        ~s|button[phx-click="toggle_org"][phx-value-feature="repository"][phx-value-org="#{org.id}"]|

      view |> element(selector) |> render_click()
      assert FeatureFlags.enabled?(:repository, org)

      view |> element(selector) |> render_click()
      refute FeatureFlags.enabled?(:repository, org)
    end

    test "unknown feature payload flashes an error and does not crash", %{conn: conn} do
      insert(:organisation)
      {:ok, view, _html} = live(conn, @path)

      html =
        render_hook(view, "toggle_org", %{
          "feature" => "bogus_feature",
          "org" => Ecto.UUID.generate()
        })

      assert html =~ "Unknown feature"
      # LiveView is still alive
      assert render(view) =~ "Feature Flags"
    end

    test "unknown org payload flashes an error and does not crash", %{conn: conn} do
      {:ok, view, _html} = live(conn, @path)

      html =
        render_hook(view, "toggle_org", %{
          "feature" => "ai_features",
          "org" => Ecto.UUID.generate()
        })

      assert html =~ "Organisation not found"
      assert render(view) =~ "Feature Flags"
    end
  end

  describe "toggle_global event" do
    test "enabling globally persists across re-renders", %{conn: conn} do
      refute FeatureFlags.enabled_globally?(:document_extraction)

      {:ok, view, _html} = live(conn, @path)

      view
      |> element(~s|button[phx-click="toggle_global"][phx-value-feature="document_extraction"]|)
      |> render_click()

      assert FeatureFlags.enabled_globally?(:document_extraction)
      assert render(view) =~ "Globally on"
    end
  end

  describe "search event" do
    test "filters the org list by name", %{conn: conn} do
      insert(:organisation, name: "Findable Org")
      insert(:organisation, name: "Hidden Org")

      {:ok, view, _html} = live(conn, @path)
      html = render_change(view, "search", %{"q" => "Findable"})

      assert html =~ "Findable Org"
      refute html =~ "Hidden Org"
    end

    test "empty search restores the full list", %{conn: conn} do
      insert(:organisation, name: "Findable Org")
      insert(:organisation, name: "Other Org")

      {:ok, view, _html} = live(conn, @path)

      render_change(view, "search", %{"q" => "Findable"})
      html = render_change(view, "search", %{"q" => ""})

      assert html =~ "Findable Org"
      assert html =~ "Other Org"
    end
  end
end
