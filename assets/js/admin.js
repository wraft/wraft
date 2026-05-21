import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { Hooks as BackpexHooks } from "backpex";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

// Manages the dynamic feature-bullets list on the Plan admin form.
// The section is wrapped in `phx-update="ignore"` so LiveView leaves the
// JS-managed DOM alone; inputs are still picked up by the parent form on
// submit via their shared `name` (set from `data-input-name`).
const FeaturesList = {
  mounted() {
    const root = this.el;
    const inputName = root.dataset.inputName;
    const template = root.querySelector("[data-features-template]");
    const rows = root.querySelector("[data-features-rows]");

    const dispatchChange = () => {
      const form = root.closest("form");
      if (form) form.dispatchEvent(new Event("input", { bubbles: true }));
    };

    root.addEventListener("click", (e) => {
      const addBtn = e.target.closest('[data-features-action="add"]');
      if (addBtn) {
        e.preventDefault();
        const node = template.content.firstElementChild.cloneNode(true);
        const input = node.querySelector("input");
        input.name = inputName;
        rows.appendChild(node);
        input.focus();
        dispatchChange();
        return;
      }

      const rmBtn = e.target.closest('[data-features-action="remove"]');
      if (rmBtn) {
        e.preventDefault();
        const row = rmBtn.closest(".features-row");
        if (row) row.remove();
        dispatchChange();
      }
    });
  },
};

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...BackpexHooks, FeaturesList },
  params: { _csrf_token: csrfToken },
});

liveSocket.connect();

BackpexHooks.BackpexThemeSelector.setStoredTheme();

window.liveSocket = liveSocket;
