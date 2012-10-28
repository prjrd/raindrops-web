// This fixes the ugliness of appending '?' to forms with method = GET
function clean_get_forms(){
    $("form[method='get']").submit(function(e){
        var href = $(this).attr('action');
        window.location = href;
        return false;
    });
}

$(document).ready(function(){
    clean_get_forms();
});
