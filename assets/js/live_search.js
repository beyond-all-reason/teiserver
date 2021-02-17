let LiveSearch = {
  init(socket) {
    var element = $("#live-search-element");

    if (element.length) {
      socket.connect();
      this.onReady(socket, element)
    }
  },

  onReady(socket, element) {
    var uid = element.attr("data-uid");
    let live_search_channel = socket.channel("live_search:endpoints:" + uid);
    
    $("body").data("live_search_channel", live_search_channel)
    
    live_search_channel.join()
      .receive("ok", resp => console.log("Live search active", resp))
      .receive("error", reason => console.log("join failed", reason))
    
    live_search_channel.on("live_search results", (resp) =>
      live_search_results(resp)
    )
  }
}
export default LiveSearch
