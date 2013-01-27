class User < Sequel::Model
    one_to_many :kickstarts
    one_to_many :cfgs
    one_to_many :jobs
    many_to_one :provider
end
