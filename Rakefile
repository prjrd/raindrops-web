require 'rubygems'
require 'yaml'

CONFIG_FILE = 'config.yaml'

# Load Configuration
begin
    CONFIG = YAML.load_file(CONFIG_FILE)
    DATABASE_URL = CONFIG[:db_url]
rescue
    raise "No config file #{CONFIG_FILE} readable/found/valid yaml syntax."
end

# http://obfuscurity.com/2011/11/Sequel-Migrations-on-Heroku
namespace :db do
    require "sequel"
    namespace :migrate do
        Sequel.extension :migration
        DB = Sequel.connect(DATABASE_URL)

        desc "Perform migration reset (full erase and migration up)"
        task :reset do
            Sequel::Migrator.run(DB, "migrations", :target => 0)
            Sequel::Migrator.run(DB, "migrations")
            puts "<= sq:migrate:reset executed"
        end

        desc "Perform migration up/down to VERSION"
        task :to do
            version = ENV['VERSION'].to_i
            raise "No VERSION was provided" if version.nil?
            Sequel::Migrator.run(DB, "migrations", :target => version)
            puts "<= sq:migrate:to version=[#{version}] executed"
        end

        desc "Perform migration up to latest migration available"
        task :up do
            Sequel::Migrator.run(DB, "migrations")
            puts "<= sq:migrate:up executed"
        end

        desc "Perform migration down (erase all data)"
        task :down do
            Sequel::Migrator.run(DB, "migrations", :target => 0)
            puts "<= sq:migrate:down executed"
        end
    end
end
