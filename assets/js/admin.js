import "phoenix_html";
import { Socket } from "phoenix";
import { LiveSocket } from "phoenix_live_view";
import { Hooks as BackpexHooks } from "backpex";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  ?.getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: { ...BackpexHooks },
  params: { _csrf_token: csrfToken },
});

liveSocket.connect();

BackpexHooks.BackpexThemeSelector.setStoredTheme();

window.liveSocket = liveSocket;
