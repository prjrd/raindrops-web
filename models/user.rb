class User < Sequel::Model
    one_to_many :kickstarts
    one_to_many :configs
    one_to_many :jobs
end

class Kickstart < Sequel::Model
    many_to_one :user

    def validate
        super
        errors.add(:name, 'cannot be empty') if !name || name.empty?
        errors.add(:body, 'cannot be empty') if !body || body.empty?
    end
end

class Configfiles < Sequel::Model
end
