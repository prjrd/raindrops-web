#!/usr/bin/env ruby

require 'rubygems'
require 'json'

module HashGet
    def get(path, object=nil)
        if path.instance_of? String
            path = path.split(":")
        end

        object ||= self

        if path.empty?
            return object
        else
            key = path.shift
            object_key = object[key]
            if object_key
                if object_key.instance_of? Array or object_key.instance_of? Hash
                    return get(path,object[key])
                else
                    if path.empty?
                        return object_key
                    else
                        return nil
                    end
                end
            else
                return nil
            end
        end
    end
end

class CfgValidator
    require 'json'
    attr_reader :errors, :cfg

    def initialize(cfg, rules)
        @errors = []

        begin
            cfg_json = JSON.parse(cfg)

        rescue
            error_raw("invalid JSON")
        end

        if cfg_json
            @cfg = cfg_json.extend(HashGet)
        end

        @rules = JSON.parse(rules)
    end

    def valid?
        return false if !@errors.empty?

        @rules.each do |key,rule|
            @key = key
            @rule = rule.extend(HashGet)
            @value = @cfg.get(@key)

            required?
            valid_values?
            requires?
            blocks?
        end
        return @errors.empty?
    end

    def required?
        if @rule["type"] == "required"
            if @value.nil?
                error "required"
            end
        end
    end

    def valid_values?
        values = @rule["values"]
        if values and @value
            if !values.include? @value
                values_str = values.join(", ")
                error "Invalid value #{@value}. Possible values: [#{values_str}]"
            end
        end
    end

    def requires?
        requires = @rule.get(["cases",@value,"requires"]) ||
                        @rule.get("requires")
        if requires
            requires.each do |p|
                if @cfg.get(p).nil?
                    error "Required attribute: #{p}"
                end
            end
        end
    end

    def blocks?
        blocks = @rule.get(["cases",@value,"blocks"]) ||
                        @rule.get("blocks")
        if blocks
            blocks.each do |p|
                if @cfg.get(p)
                    error "Incompatible attribute: #{p}"
                end
            end
        end
    end

    def error_raw(msg)
        @errors << msg
    end

    def error(msg)
        val_str = @val? "[#{@val}]" : ""
        error_raw("#{@key}#{val_str} - #{msg}")
    end
end

if __FILE__ == $0
    require 'pp'

    cfg   = File.read("lib/cfg_validator/example.cfg")
    rules = File.read("assets/cfg_rules.json")

    cfg_validator = CfgValidator.new(cfg,rules)
    pp cfg_validator.valid?
    pp cfg_validator.errors
end
