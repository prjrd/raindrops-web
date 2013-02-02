def job_status
    status = {}

    tubes = ["dispatcher", "prep", "build", "deliver", "done"]
    tubes.each{|tube| status[tube] = BS.stats_tube(tube)}

    status
end
