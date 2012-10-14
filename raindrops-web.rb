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
    locals = {
        :kickstart => {},
        :errors => {},
        :action_url => "/kickstart",
        :action_method => "post"
    }

    haml :"resource/kickstart", :locals => locals
end

get '/kickstart/:id' do
    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]

    kickstart = Kickstart.find(:id => resource_id, :user_id => user_id)

    if kickstart.nil?
        error [404, "Resource not found."]
    end

    revs = KickstartRev.where(:kickstart_id=>resource_id).order(:created_at).reverse

    locals = {
        :errors => {},
        :kickstart => kickstart.values,
        :revs => revs,
        :action_url => "/kickstart/#{resource_id}",
        :action_method => "put"
    }

    haml :"resource/kickstart", :locals => locals
end

get '/kickstart/:id/rev/:rev_id' do
    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]
    rev_id = params[:rev_id]

    kickstart = Kickstart.find(:id => resource_id, :user_id => user_id)

    if kickstart.nil?
        error [404, "Resource not found."]
    end

    rev  = KickstartRev[:id => rev_id, :kickstart_id => resource_id]
    kickstart[:body] = rev[:body]

    revs = KickstartRev.where(:kickstart_id=>resource_id).order(:created_at).reverse

    locals = {
        :errors => {},
        :kickstart => kickstart.values,
        :revs => revs,
        :action_url => "/kickstart/#{resource_id}",
        :action_method => "put"
    }

    haml :"resource/kickstart", :locals => locals
end

post '/kickstart' do
    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    kickstart = Kickstart.new

    kickstart[:name]    = params[:name]
    kickstart[:body]    = params[:body]
    kickstart[:user_id] = user_id

    if kickstart.valid?
        kickstart.save
        redirect '/'
    else
        locals = {
            :errors => kickstart.errors,
            :kickstart => kickstart.values,
            :action_url => "/kickstart",
            :action_method => "post"
        }

        haml :"resource/kickstart", :locals => locals
    end
end

put '/kickstart/:id' do
    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]

    kickstart = Kickstart.find(:id => resource_id, :user_id => user_id)

    if kickstart.nil?
        error [404, "Resource not found."]
    end

    kickstart[:name]    = params[:name]
    kickstart[:body]    = params[:body]
    kickstart[:user_id] = user_id

    if kickstart.valid?
        kickstart.save
        redirect '/'
    else
        locals = {
            :errors => kickstart.errors,
            :kickstart => kickstart.values,
            :action_url => "/kickstart/#{resource_id}",
            :action_method => "put"
        }

        haml :"resource/kickstart", :locals => locals
    end
end

delete '/kickstart/:id' do
    resource_id = params[:id]

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource = Kickstart.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    resource.destroy

    redirect '/'
end

################################################################################
# Config Files
################################################################################

put '/:resource/:id' do
    resource_name = params["resource"]

    if !RESOURCES.include?(resource_name)
        error [404, "Resource not found."]
    end

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_id = params["id"]
    resource_class = Object::const_get(resource_name.capitalize)

    if resource_id.empty?
        error [404, "Resource not found."]
    end

    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    params.each do |k,v|
        next if k == "resource"
        resource[k.to_sym] = v
    end

    if resource.valid?
        resource.save
        redirect '/'
    else
        locals = {
            :errors => resource.errors,
            :resource => resource.values,
            :action_url => "/#{resource_name}/#{resource_id}"
        }

        haml :"new/#{resource_name}", :locals => locals
    end
end

get '/:resource/:id' do
    resource_name = params[:resource]
    resource_id = params[:id]

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    if !RESOURCES.include?(resource_name)
        error [404, "Resource not found."]
    end

    resource_class = Object::const_get(resource_name.capitalize)
    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource
        locals = {
            :errors => {},
            :resource => resource,
            :action_url => "/#{resource_name}/#{resource_id}"
        }

        haml :"new/#{resource_name}", :locals => locals
    else
        error [404, "Resource not found."]
    end
end

get '/:resource/:id/delete' do
    resource_name = params[:resource]
    resource_id = params[:id]

    if !RESOURCES.include?(resource_name)
        error [404, "Resource not found."]
    end

    user_id = session[:user][:id]
    user = User.find(:id => user_id)

    resource_class = Object::const_get(resource_name.capitalize)
    resource = resource_class.find(:id => resource_id, :user_id => user_id)

    if resource.nil?
        error [404, "Resource not found."]
    end

    resource.delete

    redirect '/'
end
