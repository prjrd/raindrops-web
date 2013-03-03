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

if __FILE__ == $0
    require 'rubygems'
    require 'beanstalk-client'
    require 'pp'

    BS = Beanstalk::Pool.new(['localhost:11300'])
    BS.use("dispatcher")

    pp job_status
end
    
