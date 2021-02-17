let LoadTest = {
  init(socket) {
    var element = $("#load_test-element");
    var cnc = element.attr("data-cnc");
    
    if (cnc == "yes") {
      socket.connect();
      this.onReady_cnc(socket, element)
    } else {
      if (element.length) {
        socket.connect();
        this.onReady_tester(socket, element)
      }
    }
  },
  
  onReady_cnc(socket, element) {
    let load_test_channel = socket.channel("load_test:cnc")
    
    $("body").data("load_test_channel", load_test_channel)
    
    load_test_channel.join()
      .receive("ok", resp => console.log("Now receiving load_test CNC updates", resp))
      .receive("error", reason => console.log("join failed", reason))
    
    load_test_channel.on("new visitor", (resp) =>
      new_visitor(resp)
    )
    
    load_test_channel.on("visitor ping", (resp) =>
      visitor_ping(resp)
    )
  },

  onReady_tester(socket, element) {
    var uid = element.data("load-test-id");
    let load_test_channel = socket.channel("load_test:tester:" + uid);

    $("body").data("load_test_channel", load_test_channel)

    load_test_channel.join()
      .receive("ok", resp => console.log("Now receiving load test updates", resp))
      .receive("error", reason => console.log("join failed", reason))

    load_test_channel.on("new message", (resp) =>
      new_message(resp)
    )

    load_test_channel.on("new stats", (resp) =>
      new_stats(resp)
    )

    load_test_channel.on("tester ping", (resp) =>
      tester_ping(resp.uid)
    )
  }
}
export default LoadTest
