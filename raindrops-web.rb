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
    resource_name = "kickstart"

    locals = {
        :resource => {},
        :errors => {},
        :revs => [],
        :action_url => "/#{resource_name}",
        :action_method => "post"
    }

    haml :"resource/#{resource_name}", :locals => locals
end

get '/kickstart/:id' do
    resource_name      = "kickstart"
    resource_col_id    = :"#{resource_name}_id"
    resource_class     = Kickstart
    resource_class_rev = KickstartRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    revs = resource_class_rev.where(resource_col_id=>resource_id).order(:created_at).reverse

    locals = {
        :errors => {},
        :resource => resource.values,
        :revs => revs,
        :action_url => "/#{resource_name}/#{resource_id}",
        :action_method => "put"
    }

    haml :"resource/#{resource_name}", :locals => locals
end

get '/kickstart/:id/rev/:rev_id' do
    resource_name      = "kickstart"
    resource_col_id    = :"#{resource_name}_id"
    resource_class     = Kickstart
    resource_class_rev = KickstartRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]
    rev_id = params[:rev_id]

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    rev  = resource_class_rev[:id => rev_id, resource_col_id => resource_id]
    resource[:body] = rev[:body]

    revs = resource_class_rev.where(resource_col_id => resource_id).order(:created_at).reverse

    locals = {
        :errors => {},
        :resource => resource.values,
        :revs => revs,
        :action_url => "/#{resource_name}/#{resource_id}",
        :action_method => "put"
    }

    haml :"resource/#{resource_name}", :locals => locals
end

post '/kickstart' do
    resource_name      = "kickstart"
    resource_class     = Kickstart
    resource_class_rev = KickstartRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource = resource_class.new

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        locals = {
            :errors => resource.errors,
            :resource => resource.values,
            :action_url => "/#{resource_name}",
            :action_method => "post"
        }

        haml :"resource/#{resource_name}", :locals => locals
    end
end

put '/kickstart/:id' do
    resource_name      = "kickstart"
    resource_class     = Kickstart
    resource_class_rev = KickstartRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        locals = {
            :errors => resource.errors,
            :resource => resource.values,
            :action_url => "/#{resource_name}/#{resource_id}",
            :action_method => "put"
        }

        haml :"resource/#{resource_name}", :locals => locals
    end
end

delete '/kickstart/:id' do
    resource_class     = Kickstart

    resource_id = params[:id]

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    resource.destroy

    redirect '/'
end

################################################################################
# Config Files
################################################################################

get '/cfg' do
    resource_name = "cfg"

    locals = {
        :resource => {},
        :errors => {},
        :revs => [],
        :action_url => "/#{resource_name}",
        :action_method => "post"
    }

    haml :"resource/#{resource_name}", :locals => locals
end

get '/cfg/:id' do
    resource_name      = "cfg"
    resource_col_id    = :"#{resource_name}_id"
    resource_class     = Cfg
    resource_class_rev = CfgRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    revs = resource_class_rev.where(resource_col_id=>resource_id).order(:created_at).reverse

    locals = {
        :errors => {},
        :resource => resource.values,
        :revs => revs,
        :action_url => "/#{resource_name}/#{resource_id}",
        :action_method => "put"
    }

    haml :"resource/#{resource_name}", :locals => locals
end

get '/cfg/:id/rev/:rev_id' do
    resource_name      = "cfg"
    resource_col_id    = :"#{resource_name}_id"
    resource_class     = Cfg
    resource_class_rev = CfgRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]
    rev_id = params[:rev_id]

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    rev  = resource_class_rev[:id => rev_id, resource_col_id => resource_id]
    resource[:body] = rev[:body]

    revs = resource_class_rev.where(resource_col_id => resource_id).order(:created_at).reverse

    locals = {
        :errors => {},
        :resource => resource.values,
        :revs => revs,
        :action_url => "/#{resource_name}/#{resource_id}",
        :action_method => "put"
    }

    haml :"resource/#{resource_name}", :locals => locals
end

post '/cfg' do
    resource_name      = "cfg"
    resource_class     = Cfg
    resource_class_rev = CfgRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource = resource_class.new

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        locals = {
            :errors => resource.errors,
            :resource => resource.values,
            :action_url => "/#{resource_name}",
            :action_method => "post"
        }

        haml :"resource/#{resource_name}", :locals => locals
    end
end

put '/cfg/:id' do
    resource_name      = "cfg"
    resource_class     = Cfg
    resource_class_rev = CfgRev

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    resource[:name]    = params[:name]
    resource[:body]    = params[:body]
    resource[:user_id] = user_id

    if resource.valid?
        resource.save
        redirect '/'
    else
        locals = {
            :errors => resource.errors,
            :resource => resource.values,
            :action_url => "/#{resource_name}/#{resource_id}",
            :action_method => "put"
        }

        haml :"resource/#{resource_name}", :locals => locals
    end
end

delete '/cfg/:id' do
    resource_class     = Cfg

    resource_id = params[:id]

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    resource.destroy

    redirect '/'
end
