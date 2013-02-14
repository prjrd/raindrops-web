#!/usr/bin/env ruby

class KickstartCommand < Array
    def initialize(arguments=nil)
        if arguments.nil?
            super()
        else
            super(arguments)
        end
    end

    def single
        self.count == 1
    end

    # Return true if the command has an element matching either a string
    # or all the elements of an array of strings
    def has(*vals)
        self_type = self[0]

        if self_type.instance_of?(Array)
            self.each do |e|
                if (e & vals).sort == vals.sort
                    return true
                end
            end
        else
            return ((self & vals).sort == vals.sort)
        end

        return false
    end

    def empty
        empty = true
        self.each do |e|
            if !e.empty?
                empty = false
                break
            end
        end
        empty
    end

    alias :find :has
end

class KickstartValidator
    VALID_METHODS = %w(has count single exists)

    VALID_URLS = [
        "http://repohost.raindrops.centos.org/",
        "http://repohost.prjrd.net/",
        "http://repohost.projectraindrops.net/",
        "http://repohost/"
    ]

    attr_reader :errors

    def initialize(kickstart, *rules_files)
        @kickstart = kickstart

        @rules = Hash.new
        rules_files.each do |rules|
            @rules.merge!(JSON.parse(rules))
        end

        @errors = []
        @ks = Hash.new

        parse
    end

    def parse
        section = "main"

        @kickstart.each_line do |line|
            line.strip!

            # skip comments
            next if line =~ /^\s*#/

            # skip empty lines
            next if line.empty?

            # remove ending comments
            line.gsub!(/#.*$/,'')

            # is it a section?
            if (m = line.match(/^%(\w+)/))
                section = m[1]
                next
            end

            if section == "main"
                # get command and arguments
                line_split = line.split(" ")
                command,args = line_split[0], line_split[1..-1]

                # create array for the command if it doesn't exist
                @ks[command] = KickstartCommand.new if @ks[command].nil?

                # store args
                @ks[command] << args

            elsif section == "packages"
                @ks["packages"] = KickstartCommand.new if @ks["packages"].nil?
                @ks["packages"] << line
            end
        end
    end

    def to_hash
        @ks
    end

    def [](key)
        key = key.to_s
        @ks[key] if @ks[key]
    end

    def valid?
        return false if !@errors.empty?

        check_valid_urls?

        @rules.each do |key, rules|
            rules.each do |method, params|
                next if !VALID_METHODS.include?(method)
                args = params["args"]

                if method == "exists"
                    value = !! @ks[key]
                    expected_value = params["value"]
                    result = value == expected_value
                else
                    if @ks[key].nil?
                        error_raw("#{key} does not exist.")
                        next
                    end

                    if args
                        value = @ks[key].send(method,*args)
                    else
                        value = @ks[key].send(method)
                    end

                    expected_value = params["value"]
                    result = value == expected_value
                end

                if !result
                    error(key,method,args,value,expected_value,result)
                end
            end
        end

        return @errors.empty?
    end

    def check_valid_urls?
        @kickstart.scan(/https?:\/\/[^\s'"]*/).each do |url|
            allowed = VALID_URLS.collect do |valid_url|
                url.start_with?(valid_url)
            end.include?(true)

            if !allowed
                error_raw("#{url} is not an allowed url.")
            end
        end
    end

    def error_raw(msg)
        @errors << msg
    end

    def error(key,method,args,value,expected_value,result)
        eclass = expected_value.class
        vclass = value.class

        if args
            args = "(#{args.join(', ')})"
        end

        msg = "#{key}[#{method}#{args}] - expecting " <<
                "'#{expected_value}(#{eclass})' got '#{value}(#{vclass})'"
        @errors << msg
    end
end

if __FILE__ == $0
    require 'pp'
    require 'json'

    kickstart = File.read("../assets/kickstart.template")
    rules     = File.read("../assets/kickstart_rules.json")

    ks_validator = KickstartValidator.new(kickstart, rules)
    pp ks_validator.valid?
    pp ks_validator.errors
end
