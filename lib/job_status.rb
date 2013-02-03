def job_status
    status = {}

    tubes = ["dispatcher", "prep", "build", "deliver", "done"]
    tubes.each do |tube|
        begin
            status[tube] = BS.stats_tube(tube)
        rescue
        end
    end

    status
end
