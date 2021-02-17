let ChatApp = {
  init(socket) {
    var element = $("#chat-wrapper");
    if (element) {
      socket.connect();
      this.onReady(socket, element)
    }
  },
  
  onReady(socket, element) {
    var room_name = element.data("room_name");
    var room_names = element.data("room_names");

    if (room_name) {
      let chat_channel = socket.channel("chat:" + room_name)

      $("body").data("chat_channel", chat_channel)

      chat_channel.join()
        .receive("ok", resp => chat_join_success(room_name))
        .receive("error", reason => chat_join_failure(room_name))

      chat_channel.on("new-message", (resp) =>
        chat_incomming_message(resp)
      )
    }
    
    // Or have they joined multiple chat rooms at once?
    if (room_names) {
      let names = room_names.split(" ")
      
      for (var i = names.length - 1; i >= 0; i--) {
        let room_name = names[i]
        let chat_channel = socket.channel("chat:" + room_name)

        $("body").data("chat_channel-" + room_name, chat_channel)

        chat_channel.join()
          .receive("ok", resp => chat_join_success(room_name))
          .receive("error", reason => chat_join_failure(room_name))

        chat_channel.on("new-message", (resp) =>
          chat_incomming_message(resp, room_name)
        )
      }
    }
  }
}
export default ChatApp
