Sequel.migration do
    up do
        create_table(:providers) do
            primary_key :id
            String :name, :size => 20, :null => false, :index => true
        end

        create_table(:users) do
            primary_key :id
            Integer :provider_uid, :index => true, :null => false
            String :name, :size => 20, :null => false
            String :email, :size => 20

            foreign_key :provider_id, :providers, :null => false
        end

        create_table(:kickstarts) do
            primary_key :id
            String :name, :size => 20, :null => false
            String :body, :text => true, :null => false
            DateTime :created_at
            DateTime :updated_at

            foreign_key :user_id, :users
        end

        create_table(:kickstart_revs) do
            primary_key :id
            String :body, :text => true, :null => false
            DateTime :created_at

            foreign_key :kickstart_id, :kickstarts
        end

        create_table(:cfgs) do
            primary_key :id
            String :name, :size => 20, :null => false
            String :body, :text => true, :null => false
            DateTime :created_at
            DateTime :updated_at

            foreign_key :user_id, :users
        end

        create_table(:cfg_revs) do
            primary_key :id
            String :body, :text => true, :null => false
            DateTime :created_at

            foreign_key :cfg_id, :cfgs
        end

        create_table(:jobs) do
            primary_key :id
            String :name
            DateTime :created_at

            foreign_key :user_id, :users
            foreign_key :kickstart_id, :kickstarts
            foreign_key :cfg_id, :cfgs
        end

        create_table(:job_messages) do
            primary_key :id
            String :body, :text => true, :null => false
            DateTime :created_at

            foreign_key :job_id, :jobs
        end

        # Create providers
        %w(facebook github).each do |p|
            self[:providers].insert({:name => p})
        end
    end

    down do
        drop_table?(
            :kickstart_revs,
            :kickstarts,
            :cfg_revs,
            :cfgs,
            :job_messages,
            :jobs,
            :users,
            :providers
        )
    end
end
