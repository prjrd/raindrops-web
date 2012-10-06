ROOT_DIR = File.dirname(__FILE__)

$: << ROOT_DIR

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-twitter'
require 'omniauth-github'
require 'haml'
require 'yaml'
require 'sequel'
require 'json'
require 'pp'

CONFIG_FILE = 'config.yaml'

# Load Configuration
begin
    CONFIG = YAML.load_file(CONFIG_FILE)
    # Twitter
    twitter_key    = CONFIG[:auth][:twitter][:key]
    twitter_secret = CONFIG[:auth][:twitter][:secret]

    # GitHub
    github_key    = CONFIG[:auth][:github][:key]
    github_secret = CONFIG[:auth][:github][:secret]

    # DB
    DATABASE_URL = CONFIG[:db_url]
rescue
    raise "No config file #{CONFIG_FILE} readable/found/valid yaml syntax."
end

DB = Sequel.connect(DATABASE_URL)
require 'models/user'

enable :sessions

use Rack::Session::Cookie

use OmniAuth::Builder do
    provider :twitter, twitter_key, twitter_secret
    provider :github, github_key, github_secret
end

before do
    path = request.env["REQUEST_PATH"]
    auth_routes = [
       %r(^/auth/[^/]+/callback.*),
       '/login'
    ]

    if auth_routes.collect{|r| path.match(r)}.compact.empty?
        redirect '/login' if session[:user].nil?
    end
end

get '/' do
    locals = {:user => session[:user]}
    haml :index, :locals => locals
end

get '/login' do
    haml :login
end

get '/logout' do
    session[:user] = nil
    redirect '/'
end

# Support both GET and POST for callbacks
%w(get post).each do |method|
    send(method, "/auth/:provider/callback") do
        auth = env['omniauth.auth'] # => OmniAuth::AuthHash

        name  = auth["info"]["name"]
        email = auth["info"]["email"]

        user = User.find(:email => email)

        if user.nil?
            user = User.new
            user.name  = name
            user.email = email
            user.save
            user = user.to_hash
        end

        session[:user] = user

        redirect '/'
    end
end

# Static pages to create resources
RESOURCES = %w(kickstart config job)
get '/new/:resource' do
    resource = params["resource"]

    if !RESOURCES.include?(resource)
        error [404, "Resource not found."]
    end

    haml :"new/#{resource}", :locals => {:resource => {}, :errors => {}}
end

post '/new/:resource' do
    resource = params["resource"]

    if !RESOURCES.include?(resource)
        error [404, "Resource not found."]
    end

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_params = params.reject{|k,v| k == "resource"}
    new_resource    = Kickstart.new(resource_params)

    if new_resource.valid?
        user.add_kickstart(new_resource)
        redirect '/'
    else
        locals = {
            :errors => new_resource.errors,
            :resource => resource_params
        }

        haml :"new/#{resource}", :locals => locals
    end
end
