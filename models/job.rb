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

    def messages
        JobMessage.filter(:job_id => self.id).order(:created_at.desc).all
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

        # Validate Kickstart with specific config type
        cfg_rules = File.read(File.join(ROOT_DIR,"assets","cfg_rules.json"))

        cfg_validator = CfgValidator.new(cfg.body, cfg_rules)
        cfg_type = cfg_validator.cfg.get("type")

        if cfg_type
            # Specific KS rules file
            ks_rules_file = File.join(ROOT_DIR,"assets","kickstart_rules.json")
            ks_rules_type_file = File.join(ROOT_DIR,"assets",
                                            "kickstart_rules_#{cfg_type}.json")

            # validate KS
            if File.file?(ks_rules_type_file) \
                    and File.readable?(ks_rules_type_file)

                ks_rules = File.read(ks_rules_file)
                ks_rules_type = File.read(ks_rules_type_file)

                kickstart_validator = KickstartValidator.new(kickstart.body,
                                                                ks_rules,
                                                                ks_rules_type)

                if !kickstart_validator.valid?
                    kickstart_validator.errors.each do |e|
                        errors.add(:body,e)
                    end
                end
            end
        end
    end
end

class JobMessage < Sequel::Model
    many_to_one :job

    def before_create
        self.created_at ||= Time.now
    end
end
