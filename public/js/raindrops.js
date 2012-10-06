$(document).ready(function(){
    $.getJSON('/kickstarts',function(data){
        var kickstarts_html = "<ul>";
        for (var i=0; i<(data.length); i++) {
            var ks = data[i];
            kickstarts_html += "<li>" + ks["name"] + "</li>\n";
        }
        kickstarts_html += "</ul>\n";

        $("#kickstarts").html(kickstarts_html);
    });
});
