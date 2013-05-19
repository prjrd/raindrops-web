ROOT_DIR = File.dirname(__FILE__)

$: << ROOT_DIR

require 'rubygems'
require 'sinatra'
require 'omniauth'
require 'omniauth-twitter'
require 'omniauth-github'
require 'omniauth-facebook'
require 'haml'
require 'yaml'
require 'sequel'
require 'json'
require 'beanstalk-client'
require 'digest'
require 'pp'

# Monkey patch to get template name from within the view
module Sinatra
    module Templates
        def haml(template, options={}, locals={})
            @template = template
            render :haml, template, options, locals
        end
    end
end

CONFIG_FILE = "#{File.dirname(__FILE__)}/config.yaml"

begin
    PAGE_RESOURCES = YAML.load_file("#{File.dirname(__FILE__)}/page_resources.yaml")
rescue
end

# Load Configuration
begin
    CONFIG = YAML.load_file(CONFIG_FILE)
    # GitHub
    github_key    = CONFIG[:auth][:github][:key]
    github_secret = CONFIG[:auth][:github][:secret]

    # Facebook
    facebook_key    = CONFIG[:auth][:facebook][:key]
    facebook_secret = CONFIG[:auth][:facebook][:secret]

    # Twitter
    twitter_key    = CONFIG[:auth][:twitter][:key]
    twitter_secret = CONFIG[:auth][:twitter][:secret]

    # Session
    SESSION_SECRET = CONFIG[:session_secret]

    # DB
    DATABASE_URL = CONFIG[:db_url]
rescue
    raise "No config file #{CONFIG_FILE} readable/found/valid yaml syntax."
end

# Get admins
begin
    ADMINS = YAML.load_file('admins.yaml')
rescue
    ADMINS = nil
end

# Load templates
ks_templates = Hash.new
ks_templates_keys = Array.new
Dir['kickstart-templates/*.ks'].sort.each do |f|
    name = File.basename(f).gsub(/\.ks$/,"").gsub(/^_/,"")
    tpl = File.read(f)
    ks_templates[name] = tpl
    ks_templates_keys << name
end

KS_TEMPLATES = ks_templates
KS_TEMPLATES_KEYS = ks_templates_keys

cfg_templates = Hash.new
cfg_templates_keys = Array.new
Dir['cfg-templates/*.cfg'].sort.each do |f|
    name = File.basename(f).gsub(/\.cfg$/,"").gsub(/^_/,"")
    tpl = File.read(f)
    cfg_templates[name] = tpl
    cfg_templates_keys << name
end

CFG_TEMPLATES = cfg_templates
CFG_TEMPLATES_KEYS = cfg_templates_keys

# Get Sequel database
DB = Sequel.connect(DATABASE_URL)

# Open beanstalk connection
BS = Beanstalk::Pool.new(['localhost:11300'])
BS.use("dispatcher")

# Load models
Dir['models/*.rb'].each{|m| require m}

# Load libs
Dir['lib/*.rb'].each{|m| require m}

use Rack::Session::Cookie,  :expire_after => 7*24*60*60,
                            :secret => CONFIG[:session_secret]

use OmniAuth::Builder do
    provider :github, github_key, github_secret
    provider :twitter, twitter_key, twitter_secret
end

helpers do

    # This helper loads the resources specified in the PAGE_RESOURCES yaml
    # for a specific view. It's desgined to be called from within a view.
    def load_resources
        if defined? PAGE_RESOURCES
            load = String.new
            if (resources = PAGE_RESOURCES[@template])
                if (js_files = resources[:js])
                    resources[:js].each do |js|
                        load << \
                        "<script src='#{js}' type='text/javascript'></script>"
                    end
                end

                if (css_files = resources[:css])
                    resources[:css].each do |css|
                        load << \
                        "<link href='#{css}' rel='stylesheet' />"
                    end
                end
            end
            load if !load.empty?
        end
    end
end

before do
    path = request.env["REQUEST_URI"]
    auth_routes = [
       %r(^/auth/[^/]+/callback.*),
       '/login'
    ]

    user_id = request.cookies["user_id"]

    if auth_routes.collect{|r| path.match(r)}.compact.empty?
        if session[:user].nil? or user_id != session[:user][:id].to_s
            redirect '/login'
        end
    end
end

get '/' do
    user = User.find(:id => session[:user][:id])

    locals = {:user => user}
    haml :index, :locals => locals
end

get '/login' do
    session.clear
    response.delete_cookie("user_id")
    haml :login, :layout => false
end

get '/logout' do
    redirect '/login'
end

get '/status' do
    haml :status, :locals => {:status => job_status}
end

get '/bug' do
    haml :bug
end


# Support both GET and POST for callbacks
%w(get post).each do |method|
    send(method, "/auth/:provider/callback") do
        auth = env['omniauth.auth']

        provider = params["provider"]

        begin
            provider_id = Provider[:name => provider][:id]
        rescue
            error [404, "Provider not found."]
        end

        provider_uid = auth["uid"]

        name  = auth["info"]["name"] || auth["info"]["nickname"]
        name = auth["info"]["nickname"] if name.nil? or name.empty?

        email = auth["info"]["email"] || ""
        image = auth["info"]["image"]

        if name.nil? or name.empty?
            error [
                404,
                "Fill in your username or nickname in #{provider}."
            ]
        end

        user = User[:provider_id => provider_id, :provider_uid => provider_uid]

        if user.nil?
            user = User.new
            user.name  = name
            user.email = email
            user.provider_id  = provider_id
            user.provider_uid = provider_uid
        else
            user.name = name
            user.email = email
        end

        user.save

        response.set_cookie("user_id", {
                                        :value => user[:id],
                                        :path => "/",
                                        :expires => Time.now + 7*24*60*60}
                            )


        session[:user] = user.to_hash
        session[:avatar] = image if image

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
        redirect '/#tab_kickstart'
    else
        haml r.view, r.locals
    end
end

put '/kickstart/:id' do
    user_id = session[:user][:id]

    r = ResourceKickstart.new(
            :user_id => user_id,
            :action_method => "put",
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
        redirect '/#tab_kickstart'
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

    redirect '/#tab_kickstart'
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
        redirect '/#tab_config'
    else
        haml r.view, r.locals
    end
end

put '/cfg/:id' do
    user_id = session[:user][:id]

    r = ResourceCfg.new(
            :user_id => user_id,
            :action_method => "put",
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
        redirect '/#tab_config'
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

    redirect '/#tab_config'
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

get '/json/job' do
    content_type 'application/json'
    user_id = session[:user][:id]
    user = User[:id => user_id]

    user.jobs.collect do |job|
        messages = job.messages.collect{|m| m.to_hash}
        job = job.to_hash
        job[:messages] = messages
        job
    end.to_json
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
        job.submit
        redirect '/#tab_job'
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

    redirect '/#tab_job'
end

################################################################################
# dynamic js
################################################################################
get '/js/ks_templates.js' do
    content_type "application/x-javascript"

    "var ks_templates = " << KS_TEMPLATES.to_json
end

get '/js/cfg_templates.js' do
    content_type "application/x-javascript"

    "var cfg_templates = " << CFG_TEMPLATES.to_json
end
