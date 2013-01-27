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
