// We need to import the CSS so that webpack will load it.
// The MiniCssExtractPlugin is used to separate it out into
// its own CSS file.
import "phoenix_html"
import {Socket} from "phoenix"
import NProgress from "nprogress"
import {LiveSocket, debug} from "phoenix_live_view"

// Import local files
//
// Local files can be imported directly using relative paths, for example:
import socket from "./socket"
import LoadTest from "./load_test"
import LiveSearch from "./live_search"
import ChatApp from "./chat"
import CommunicationNotification from "./communication_notification"

$(function() {
  LoadTest.init(socket);
  LiveSearch.init(socket);
  ChatApp.init(socket);
  CommunicationNotification.init(socket);
});

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content");
// let liveSocket = new LiveSocket("/live", Socket, {params: {_csrf_token: csrfToken}});

let liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken},
  metadata: {
    click: (e, el) => {
      return {
        altKey: e.altKey,
        shiftKey: e.shiftKey,
        ctrlKey: e.ctrlKey,
        metaKey: e.metaKey,
        x: e.x || e.clientX,
        y: e.y || e.clientY,
        pageX: e.pageX,
        pageY: e.pageY,
        screenX: e.screenX,
        screenY: e.screenY,
        offsetX: e.offsetX,
        offsetY: e.offsetY,
        detail: e.detail || 1,
      }
    },
    keydown: (e, el) => {
      return {
        altGraphKey: e.altGraphKey,
        altKey: e.altKey,
        code: e.code,
        ctrlKey: e.ctrlKey,
        key: e.key,
        keyIdentifier: e.keyIdentifier,
        keyLocation: e.keyLocation,
        location: e.location,
        metaKey: e.metaKey,
        repeat: e.repeat,
        shiftKey: e.shiftKey
      }
    }
  }
})

window.addEventListener("phx:page-loading-start", info => NProgress.start())
window.addEventListener("phx:page-loading-stop", info => NProgress.done())


// let liveSocket = new LiveSocket("/live", Socket)
liveSocket.connect()
window.liveSocket = liveSocket
