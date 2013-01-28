class User < Sequel::Model
    one_to_many :kickstarts
    one_to_many :cfgs
    one_to_many :jobs
    many_to_one :provider

    def after_create
        super
        notify_admin
    end

    def notify_admin
        subject = "New raindrops user"
        message = <<-END.gsub(/^ {8}/,"")
        Hello,

        the user #{self.name} <#{self.email}> has just registered using #{self.provider.name}.
        END

        email_admin(subject,message)
    end
end
