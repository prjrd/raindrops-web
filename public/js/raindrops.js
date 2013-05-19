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
  $("#bgCfg.btn-group button").click(function(){
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

var ks_import_edit= "";
var ks_import_last_option = "---";
function setup_import_ks_listener(){
  $("#importKS").change(function(){
    name = $(this).val();
    if (name == "---") {
      $("#textareaBody").val(ks_import_edit);
    } else {
      if (ks_import_last_option == "---") {
        ks_import_edit = $("#textareaBody").val();
      }
      $("#textareaBody").val(ks_templates[name]);
    }
    ks_import_last_option = name;
  });
}

var cfg_import_edit= "";
var cfg_import_last_option = "---";
function setup_import_cfg_listener(){
  $("#importCFG").change(function(){
    name = $(this).val();
    if (name == "---") {
      $("#textareaBody").val(cfg_import_edit);
    } else {
      if (cfg_import_last_option == "---") {
        cfg_import_edit = $("#textareaBody").val();
      }
      $("#textareaBody").val(cfg_templates[name]);
    }
    cfg_import_last_option = name;
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
    setup_import_ks_listener();
    setup_import_cfg_listener();
    start_tooltips();
});
