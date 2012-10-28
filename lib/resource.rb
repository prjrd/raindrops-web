class Resource
    attr_accessor :resource

    def initialize(h = {})
        resource_desc = self.class::RESOURCE_DESC

        @name = resource_desc[:name]
        @model_class     = resource_desc[:model_class]
        @model_class_rev = resource_desc[:model_class_rev]

        @resource_col_id = :"#{@name}_id"

        # Resource ID
        @id = h[:id]

        # User
        if h[:user_id]
            @user = User.find(:id => h[:user_id])
        end

        # Action method
        @action_method = h[:action_method] || "post"
    end

    def create
        @new_resource = @model_class.new
    end

    def load
        @resource = @model_class.find(:id => @id, :user_id => @user[:id])
    end

    def nil?
        @resource.nil?
    end

    def find_rev(rev_id)
        @model_class_rev[:id => rev_id, @resource_col_id => @id]
    end

    def revs
        if nil?
            []
        else
            r = @model_class_rev.where(@resource_col_id => @id)
            r.order(:created_at).reverse
        end
    end

    def errors
        if @new_resource
            @new_resource.errors
        else
            nil
        end
    end

    def values
        if @new_resource
            @new_resource.values
        else
            if nil?
                {}
            else
                @resource.values
            end
        end
    end


    def action_url
        case @action_method
        when "post"
            "/#{@name}"
        when "put"
            "/#{@name}/#{@id}"
        else
            ""
        end.to_sym
    end

    def locals
        {
            :locals => {
                :resource => values,
                :errors => errors,
                :revs => revs,
                :action_method => @action_method,
                :action_url => action_url
            }
        }
    end

    def view
        "resource/#{@name}".to_sym
    end
end

class ResourceKickstart < Resource
    RESOURCE_DESC = {
        :name => "kickstart",
        :model_class => Kickstart,
        :model_class_rev => KickstartRev
    }
end

class ResourceCfg < Resource
    RESOURCE_DESC = {
        :name => "cfg",
        :model_class => Cfg,
        :model_class_rev => CfgRev
    }
end
