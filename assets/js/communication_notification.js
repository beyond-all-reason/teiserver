let CommunicationsNotification = {
  init(socket, element) {
    var element = $("#communication-notifications-wrapper")
    if (element) {
      let user_id = element.data("user-id");
      socket.connect();
      this.onReady(user_id, socket)
    }

    var key = $("#communications-reload").data("key")
    if (key) {
      socket.connect();
      this.reloadReady(key, socket)
    }
  },
  
  newNotification(notification) {
    // If it contains a # then we need to put that at the end of it after
    // inserting the anid
    var parts = notification.redirect.split("#");
    // console.log(parts);
    
    if (parts.legnth == 1) {
      var redirect_pre = parts
      var redirect_post = ""
    } else {
      var redirect_pre = parts[0];
      var redirect_post = "#" + parts[1];
    }
    
    // If it contains a question mark then we
    // want to append using an ampersand
    if (redirect_pre.indexOf("?") > 0) {
      var url = redirect_pre + '&anid=' + notification.id + redirect_post;
    } else {
      var url = redirect_pre + '?anid=' + notification.id + redirect_post;
    }
    
    var new_div = '<a href="' + url + '" class="dropdown-item" id="communication-notifications-li-' + notification.id + '">'
      new_div += '<i class="far fa-fw ' + notification.icon + '" style="color: ' + notification.colour + '"></i>'
      new_div += ' '
      new_div += '<strong style="color:' + notification.colour + '">' + notification.title + '</strong><br />'
      
      new_div += notification.body;
    new_div += '</a>';

    this.ringBell();
    $("#communication-notifications-dropdown-list").prepend(new_div);
  },

  ringBell() {
    var v = $("#communication-notifications-badge").html();

    if (v.trim() == "0") {
      v = "1";
      $("#communication-notifications-empty-marker").hide();
      $("#communication-notifications-icon").addClass("text-info");
      $("#communication-notifications-badge").removeClass("badge-outline-primary");
      $("#communication-notifications-badge").addClass("badge-outline-info");
      $("#communication-notifications-icon").removeClass("far");
      $("#communication-notifications-icon").addClass("fas");
    } else {
      v = parseInt(v) + 1;
    }

    $("#communication-notifications-badge").html(v);
    var e = $("#communication-notifications-icon-wrapper");

    e.animate({opacity: 0.25,}, 200, function() {
      e.animate({opacity: 1,}, 200, function() {
        e.animate({opacity: 0.25,}, 200, function() {
          e.animate({opacity: 1,}, 200, function() {
            e.animate({opacity: 0.25,}, 200, function() {
              e.animate({opacity: 1,}, 200, function() {
                e.animate({opacity: 0.25,}, 200, function() {
                  e.animate({opacity: 1,}, 200, function() {
                    
                  });
                });
              });
            });
          });
        });
      });
    });
  },
  
  onReady(user_id, socket) {
    if (user_id != undefined) {
      let div_output = $("#messages");
      let div_input = $("#chat-input");
      
      let notificationChannel = socket.channel("communication_notification:" + user_id);
      
      notificationChannel.join()
        // .receive("ok", resp => console.log("Now receiving notifications", resp))
        .receive("error", reason => console.log("join failed", reason))
      
      notificationChannel.on("new communication notifictation", (resp) =>
        this.newNotification(resp)
      )
    }
  },
  
  reloadReady(key, socket) {
    let reloadChannel = socket.channel("communication_reloads:" + key);

    reloadChannel.join()
      // .receive("ok", resp => console.log("Now receiving reloads", resp))
      .receive("error", reason => console.log("join failed", reason))

    reloadChannel.on("reload", (resp) =>
      location.reload()
    )
  }
}
export default CommunicationsNotification