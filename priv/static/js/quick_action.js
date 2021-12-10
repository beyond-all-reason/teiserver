var page_quick_actions = [];

var current_qa_selection = 0;
var quick_action_url = '';

var qa_isCtrl = false;
var qa_isShift = false;

// Now you get to pick which key it is
var qa_f_key = 70;
var qa_p_key = 80;
var qa_l_key = 76;
var qa_ast_key = 106;
var f10_key = 121;
var qa_apost_key = 223;
var qa_hash_key = 222;
var qa_period = 190;

var qa_down_arrow = 40;
var qa_up_arrow = 38;
var qa_enter = 13;

var qa_hotkey = qa_period;
var qa_item_list = null;

var qa_test_mode = false;

var min_icon_count = 2

$(function() {
  $('#quick-action-modal').on('hidden.bs.modal', function () {
    $("#modal-fixer").hide();
  })
  
  $('#quick-action-modal').on('shown.bs.modal', function () {
    $('#quick_action_text').trigger('focus')
  })
  
  // $('body').after('<div id="quick_action_dialog" style="display:none;" title="">\
  //     <input type="text" id="quick_action_text" value="" style="width:99%;"/>\
  //     <div id="quick_action_list" style="max-height:' + ($(window).height()-300) + 'px;">\
  //         &nbsp;\
  //     </div>\
  // </div><div id="quick_action_form" style="display:none;"></div><div id="quick_action_cache" style="display:none;"></div>');
  
  $('#quick_action_text').keyup(function(e) {
    if (e.which != qa_down_arrow && e.which != qa_up_arrow && e.which != qa_enter)
    {
      update_quick_action_modal(true);
    }
  });
  
  $('#quick_action_text').keydown(function(e) {
    if(e.which == qa_enter) {
      var search_term = $('#quick_action_text').val().toLowerCase();
      select_goto(search_term);
      e.preventDefault();
    }
    else if(e.which == qa_down_arrow)
    {
      current_qa_selection += 1;
      update_quick_action_modal(false);
      e.preventDefault();
    }
    else if(e.which == qa_up_arrow)
    {
      current_qa_selection -= 1;
      if (current_qa_selection < 0)
      {
        current_qa_selection = 0;
      }
      update_quick_action_modal(false);
      e.preventDefault();
    }
  });

  // This is where we check to see if we bring up the window
  $(document).keyup(function(e) {
      if(e.which == 17) {
          qa_isCtrl = false;
      }
      if(e.which == 16) {
          qa_isShift = false;
      }
  });
  // action on key down
  $(document).keydown(function(e) {
    if(e.which == 17) {
      qa_isCtrl = true;
    }
    if(e.which == 16) {
      qa_isShift = true;
    }
    if((e.which == qa_hotkey || e.which == qa_apost_key) && qa_isCtrl) {
      show_quick_action_modal();
    }
  });
  
  // When testing it can be useful to uncomment the following line
  if (qa_test_mode) {show_quick_action_modal();}
});

// This function performs the actual filtering

// It expects the items in the form:
// [name, label, [search_terms], use_modal]

function filter_gotos (search_term)
{
  var found_items = [];
  
  var search_terms = search_term.toLowerCase().split(" ");
  
  // For each possible item we can go to
  for (var i = 0; i < qa_item_list.length; i++)
  {
    the_item = qa_item_list[i];
    use_this_item = false;
    
    // No search term? List all the items
    if (search_terms == [""]) {
      use_this_item = true
      continue;
    }
    
    // For each searchable term this item has
    var terms = the_item.keywords;
    for (var j = 0; j < terms.length; j++)
    {
      if (use_this_item == true) {continue;}
      
      haystack = terms[j].toLowerCase();
      contaiqa_all_parts = true;
      
      // For each of our search terms
      for (var k = 0; k < search_terms.length; k++)
      {
        if (search_terms[k] === "") {continue;}
        if (haystack.indexOf(search_terms[k]) == -1)
        {
          contaiqa_all_parts = false;
        }
      }
      
      if (contaiqa_all_parts)
      {
        use_this_item = true;
      }
    }
    
    if (use_this_item)
    {
      found_items.push(the_item);
    }
  }
  
  return found_items;
}

function select_goto (search_term)
{
    var found_items = filter_gotos(search_term);
    var the_item = found_items[current_qa_selection]
    
    if (the_item.input != null) {
      show_form_dialog(the_item)
    }
    else if (the_item.url != null) {
      document.location = the_item.url;
    }
    else if (the_item.js != null) {
      the_item.js();
    }
    
    
    /*
    May want to use this with a more complex form, leaving it in for future reference
    if (jQuery.isEmptyObject(form))
    {
        document.location = '${request.route_url('quick_action.action')}?n=' + found_items[current_qa_selection][0];
    }
    else
    {
        alert("No handler");
    }
    */
}

function show_form_dialog (the_item)
{
  $('#quick-action-modal').modal('hide');
  
  $('#quick-action-form').attr("action", the_item.url);
  $('#quick-action-form-input').attr("name", the_item.input);
  if (the_item.method == "get") {
    $('#quick-action-form').attr("method", "GET");
  }
  $('#quick-action-form-input').attr("placeholder", the_item.placeholder);

  icon_str = make_icon_string(the_item.icons)
  $('#quick-action-form-heading').html(icon_str + " " + the_item.label);
  
  $('#quick-action-form-modal').modal({});
  $('#quick-action-form-input').focus();
}

function make_icon_string(icons) {
  mapped_icons = icons.map(function (i) {
    return "<i class='fa-fw " + i + "'></i> "
  })
  
  while (mapped_icons.length < min_icon_count) mapped_icons = mapped_icons.concat(["&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"]);
  
  return mapped_icons.join("")
}

function build_quick_action_list (search_term, reset)
{
    if (reset) {current_qa_selection=0};
    
    var output = "";
    var found_items = filter_gotos(search_term);
    
    if (current_qa_selection >= found_items.length)
    {
      current_qa_selection = found_items.length-1;
    }
    
    output = "";
    
    for (var i = 0; i < found_items.length; i++)
    {
      the_item = found_items[i];
      
      extra_class = '';
      if (i == current_qa_selection) {
        extra_class = "qa-row-active";
      }

      icon_str = "";
      if (the_item.icons) {
        icon_str = make_icon_string(the_item.icons)
      }

      output += "<a onclick='alert(\"You need to use the up and down arrows along with the enter key to select options\"); $(\"#quick_action_text\").focus();' class='qa-row " + extra_class + "'>" + icon_str + "&nbsp;&nbsp;" + the_item.label + "</a>";
    }
    
    return output;
}

/*
If we call this and it wraps a check around the actual showing to ensure
we've got some links to show.
*/
function show_quick_action_modal () {
    if (qa_item_list == null)
    {
      $.ajax({
        url: quick_action_url,
        type: 'get',
        async: false,
        cache: false,
        success: function(data) {
          qa_item_list = page_quick_actions.concat(data);
          if (qa_item_list != [])
          {
            actually_show_quick_action_modal();
          }
        }
      });
    }
    else
    {
      if (qa_item_list != "")
      {
        actually_show_quick_action_modal();
      }
    }
}

function actually_show_quick_action_modal () {
  $('#quick_action_text').val("");
  $('#quick_action_list').html("");
  search_term = "";
  var quick_action_list = build_quick_action_list(search_term, true);
  
  if (quick_action_list != "")
  {
    // var ft = setTimeout(function() {if ($('#quick_action_text').text() == ''){$('#quick_action_text').focus();}}, 500);
    
    $('#quick_action_list').html(quick_action_list);
    
    $("#modal-fixer").show();
    $('#quick-action-modal').modal({});
    
    // if ($('#quick_action_text').text() == ''){$('#quick_action_text').focus();}
    
    // var ft = setTimeout(function() {if ($('#quick_action_text').text() == ''){$('#quick_action_text').focus();}}, 100);
    
    // setTimeout(function() {
    //   console.log($('#quick-action-form-input').is(":focus"));
      
    //   if ($('#quick-action-form-input').is(":focus")) {
    //     $('#quick-action-form-input').focus();
    //   }
    // }, 500);
  }
}

function update_quick_action_modal (reset)
{
  search_term = $('#quick_action_text').val().toLowerCase();
  var quick_action_list = build_quick_action_list(search_term, reset);
  
  $('#quick_action_list').html(quick_action_list);
}