class User < Sequel::Model
    one_to_many :kickstarts
    one_to_many :cfgs
    one_to_many :jobs
end

class Kickstart < Sequel::Model
    many_to_one :user
    one_to_many :kickstart_revs

    def save_kickstart_rev
        ks_rev = KickstartRev.new

        ks_rev[:kickstart_id] = self.id
        ks_rev[:body]         = self.body

        ks_rev.save
    end

    def before_create
        self.created_at ||= Time.now
        self.updated_at ||= Time.now
    end

    def after_create
        super
        save_kickstart_rev
    end
    def after_update
        super
        save_kickstart_rev
    end

    def before_save
        self.updated_at = Time.now
        super
    end

    def after_save
        super
    end

    def after_destroy
        super
        KickstartRev.where(:kickstart_id => self.id).destroy
    end

    def validate
        super
        errors.add(:name, 'cannot be empty') if !name || name.empty?
        errors.add(:body, 'cannot be empty') if !body || body.empty?

        # Kickstart Validate
        rules = File.read(File.join(ROOT_DIR,"assets","kickstart_rules.json"))

        kickstart_validator = KickstartValidator.new(body, rules)
        if !kickstart_validator.valid?
            kickstart_validator.errors.each do |e|
                errors.add(:body,e)
            end
        end

    end
end

class KickstartRev < Sequel::Model
    many_to_one :kickstart

    def before_create
        self.created_at ||= Time.now
    end
end

class Cfg < Sequel::Model
    many_to_one :user
    one_to_many :cfg_revs

    def save_cfg_rev
        cfg_rev = CfgRev.new

        cfg_rev[:cfg_id] = self.id
        cfg_rev[:body]   = self.body

        cfg_rev.save
    end

    def before_create
        self.created_at ||= Time.now
        self.updated_at ||= Time.now
    end

    def after_create
        super
        save_cfg_rev
    end
    def after_update
        super
        save_cfg_rev
    end

    def before_save
        self.updated_at = Time.now
        super
    end

    def after_save
        super
    end

    def after_destroy
        super
        CfgRev.where(:cfg_id => self.id).destroy
    end

    def validate
        super
        errors.add(:name, 'cannot be empty') if !name || name.empty?
        errors.add(:body, 'cannot be empty') if !body || body.empty?

        # CFG Validate
        rules = File.read(File.join(ROOT_DIR,"assets","cfg_rules.json"))

        cfg_validator = CfgValidator.new(body, rules)
        if !cfg_validator.valid?
            cfg_validator.errors.each do |e|
                errors.add(:body,e)
            end
        end
    end
end

class CfgRev < Sequel::Model
    many_to_one :cfg

    def before_create
        self.created_at ||= Time.now
    end
end

class Job < Sequel::Model
    many_to_one :kickstart
    many_to_one :cfg
    many_to_one :user
    one_to_many :job_messages

    def before_create
        self.created_at ||= Time.now
    end

    def after_create
        self.add_job_message(:body => "Submitted")
    end

    def after_destroy
        super
        JobMessage.where(:job_id => self.id).destroy
    end

    def current_message
        JobMessage.filter(:job_id => self.id).order(:created_at.desc).first
    end

    def validate
        super

        errors.add(:name, 'cannot be empty') if !name || name.empty?

        if kickstart_id
            kickstart = Kickstart[:id => kickstart_id, :user_id => user_id]
            errors.add(:kickstart,'resource not found') if kickstart.nil?
        else
            errors.add(:kickstart, 'cannot be empty')
        end

        if cfg_id
            cfg = Cfg[:id => cfg_id, :user_id => user_id]
            errors.add(:cfg,'resource not found') if cfg.nil?
        else
            errors.add(:cfg, 'cannot be empty')
        end
    end

end

class JobMessage < Sequel::Model
    many_to_one :job

    def before_create
        self.created_at ||= Time.now
    end
end
