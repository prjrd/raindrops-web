// This fixes the ugliness of appending '?' to forms with method = GET
function clean_get_forms(){
    $("form[method='get']").submit(function(e){
        var href = $(this).attr('action');
        window.location = href;
        return false;
    });
}

function update_tab_url(){
  var hash = window.location.hash;
  hash && $('ul.nav a[href="' + hash + '"]').tab('show');

  $('.nav-tabs a').click(function (e) {
    $(this).tab('show');
    var scrollmem = $('body').scrollTop();
    window.location.hash = this.hash;
    $('html,body').scrollTop(scrollmem);
  });
}

function setup_new_cfg_listener(){
  $(".btn-group button").click(function(){
    var action = $(this).val();

    switch(action)
    {
    case "new":
      $("#select-config").fadeOut(function(){
        $("#new-config").fadeIn();
      });
      break;

    case "existing":
      $("#new-config").fadeOut(function(){
        $("#select-config").fadeIn();
      });
      break;
    }
  });
}

function start_tooltips(){
  $(".mtooltip").tooltip({
    "placement":"top"
  });
}
$(function(){
    clean_get_forms();
    update_tab_url();
    setup_new_cfg_listener();
    start_tooltips();
});
