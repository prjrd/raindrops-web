function init_jobs_table(){
    return $("#jobs_table").dataTable({
        "aoColumns": [
            { "sTitle": "Job Name" },
            { "sTitle": "Status" },
            { "sTitle": "Date" },
            { "sTitle": "Actions" }
        ]
    });
};

function update_jobs_table(jobs_table){
    $.getJSON("/json/job",function(data){
        var aaData = [];

        var id;
        var name;
        var messages;
        var status;
        var timestamp;
        var actions;

        $.each(data,function(key, val){
            id = val["id"];
            name = val["name"];
            messages = val["messages"];
            sha256 = val["sha256"];

            if (messages.length > 0) {
                status = messages[0]["body"];
                timestamp = messages[0]["created_at"];
            } else {
                status = "-";
                timestamp = val["created_at"];
            }

            actions = "<form action='/job/" + id + "' class='strip' method='get'>" +
            "    <button class='btn btn-primary' type='submit'>Open</button>" +
            "</form>" +
            "<form action='/job/" + id + "' class='strip' method='post'>" +
            "    <input name='_method' type='hidden' value='delete' />" +
            "    <button class='btn btn-danger' type='submit'>Delete</button>" +
            "</form>" +
            "&nbsp;<a class='btn' href='http://jobhost.raindrops.centos.org/" + sha256 + "/'>"+
            "Results</a>";

            aaData.push([name,status,timestamp,actions]);
        });

        update_table(jobs_table,aaData);
    });
};


function update_table(dataTable, data){
    if (dataTable) {
        dataTable.fnClearTable();
        dataTable.fnAddData(data);
        dataTable.fnDraw(false);
    };
    clean_get_forms();
};

$(document).ready(function(){
    var jobs_table = init_jobs_table();
    update_jobs_table(jobs_table);
    setInterval(function(){update_jobs_table(jobs_table);},10000);
});
