class User < Sequel::Model
    one_to_many :kickstarts
    one_to_many :configfiles
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
    end
end

class KickstartRev < Sequel::Model
    many_to_one :Kickstart

    def before_create
        self.created_at ||= Time.now
    end
end

class Configfile < Sequel::Model
    many_to_one :user
end
