ROOT_DIR = File.dirname(__FILE__)

$: << ROOT_DIR

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-github'
require 'omniauth-facebook'
require 'haml'
require 'yaml'
require 'sequel'
require 'json'
require 'pp'

CONFIG_FILE = 'config.yaml'

# Load Configuration
begin
    CONFIG = YAML.load_file(CONFIG_FILE)
    # GitHub
    github_key    = CONFIG[:auth][:github][:key]
    github_secret = CONFIG[:auth][:github][:secret]

    # Facebook
    facebook_key    = CONFIG[:auth][:facebook][:key]
    facebook_secret = CONFIG[:auth][:facebook][:secret]

    # Session
    SESSION_SECRET = CONFIG[:session_secret]

    # DB
    DATABASE_URL = CONFIG[:db_url]
rescue
    raise "No config file #{CONFIG_FILE} readable/found/valid yaml syntax."
end

DB = Sequel.connect(DATABASE_URL)

require 'models/user'
require 'lib/resource'
require 'lib/cfg_validator'
require 'lib/kickstart_validator'

enable :sessions

use Rack::Session::Pool, :key => SESSION_SECRET
use Rack::Session::Cookie

use OmniAuth::Builder do
    provider :github, github_key, github_secret
    provider :facebook, facebook_key, facebook_secret
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
    user = User.find(:id => session[:user][:id])

    locals = {:user => user}
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

        auth = env['omniauth.auth']

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

################################################################################
# Kickstarts
################################################################################

get '/kickstart' do
    r = ResourceKickstart.new
    haml r.view, r.locals
end

get '/kickstart/:id' do
    r = ResourceKickstart.new(
            :user_id => session[:user][:id],
            :id => params["id"],
            :action_method => "put"
        )

    if !r.load
        error [404, "Resource not found."]
    end

    haml r.view, r.locals
end

get '/kickstart/:id/rev/:rev_id' do
    r = ResourceKickstart.new(
            :user_id => session[:user][:id],
            :id => params["id"],
            :action_method => "put"
        )

    if !r.load
        error [404, "Resource not found."]
    end

    rev_id = params[:rev_id]
    rev = r.find_rev(rev_id)

    if !rev
        error [404, "Revision not found."]
    end

    r.resource[:body] = rev[:body]

    haml r.view, r.locals
end

post '/kickstart' do
    user_id = session[:user][:id]

    r = ResourceKickstart.new(
            :user_id => user_id,
            :id => params["id"]
        )

    resource = r.create

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        haml r.view, r.locals
    end
end

put '/kickstart/:id' do
    user_id = session[:user][:id]

    r = ResourceKickstart.new(
            :user_id => user_id,
            :id => params["id"]
        )


    if !r.load
        error [404, "Resource not found."]
    end

    resource = r.resource

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        haml r.view, r.locals
    end
end

delete '/kickstart/:id' do
    r = ResourceKickstart.new(
            :user_id => session[:user][:id],
            :id => params["id"]
        )

    if !r.load
        error [404, "Resource not found."]
    end

    r.resource.destroy

    redirect '/'
end

################################################################################
# Config Files
################################################################################

get '/cfg' do
    r = ResourceCfg.new
    haml r.view, r.locals
end

get '/cfg/:id' do
    r = ResourceCfg.new(
            :user_id => session[:user][:id],
            :id => params["id"],
            :action_method => "put"
        )

    if !r.load
        error [404, "Resource not found."]
    end

    haml r.view, r.locals
end

get '/cfg/:id/rev/:rev_id' do
    r = ResourceCfg.new(
            :user_id => session[:user][:id],
            :id => params["id"],
            :action_method => "put"
        )

    if !r.load
        error [404, "Resource not found."]
    end

    rev_id = params[:rev_id]
    rev = r.find_rev(rev_id)

    if !rev
        error [404, "Revision not found."]
    end

    r.resource[:body] = rev[:body]

    haml r.view, r.locals
end

post '/cfg' do
    user_id = session[:user][:id]

    r = ResourceCfg.new(
            :user_id => user_id,
            :id => params["id"]
        )

    resource = r.create

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        haml r.view, r.locals
    end
end

put '/cfg/:id' do
    user_id = session[:user][:id]

    r = ResourceCfg.new(
            :user_id => user_id,
            :id => params["id"]
        )


    if !r.load
        error [404, "Resource not found."]
    end

    resource = r.resource

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        haml r.view, r.locals
    end
end

delete '/cfg/:id' do
    r = ResourceCfg.new(
            :user_id => session[:user][:id],
            :id => params["id"]
        )

    if !r.load
        error [404, "Resource not found."]
    end

    r.resource.destroy

    redirect '/'
end

################################################################################
# Jobs
################################################################################

get '/job' do
    user_id = session[:user][:id]
    user = User[:id => user_id]

    locals = {
        :job => {},
        :errors => nil,
        :kickstarts => user.kickstarts,
        :cfgs => user.cfgs
    }

    haml :job_new, :locals => locals
end

get '/job/:id' do
    user_id = session[:user][:id]
    id = params[:id]

    job = Job[:id => id, :user_id => user_id]

    if job.nil?
        error [404, "Resource not found."]
    end

    locals = {
        :job => job
    }

    haml :job, :locals => locals
end

post '/job' do
    user_id = session[:user][:id]
    user = User[:id => user_id]

    kickstart_id = params[:kickstart_id]
    cfg_id = params[:cfg_id]

    job = Job.new

    job[:kickstart_id] = kickstart_id
    job[:cfg_id] = cfg_id
    job[:name] = params[:name]
    job[:user_id] = user_id

    if job.valid?
        job.save
        redirect '/'
    else
        locals = {
            :errors => job.errors,
            :job => job.values,
            :kickstarts => user.kickstarts,
            :cfgs => user.cfgs,
            :action_url => "/job"
        }

        haml :job_new, :locals => locals
    end
end

delete '/job/:id' do
    user_id = session[:user][:id]
    id = params[:id]

    job = Job[:id => id, :user_id => user_id]

    if job.nil?
        error [404, "Resource not found."]
    end

    job.destroy

    redirect '/'
end

