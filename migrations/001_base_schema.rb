Sequel.migration do
    up do
        create_table(:users) do
            primary_key :id
            String :name, :size => 20, :null => false
            String :email, :size => 20, :null => false
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

        create_table(:configfiles) do
            primary_key :id
            String :name, :size => 20, :null => false
            String :body, :text=>true,  :null => false

            foreign_key :user_id, :users
        end

        create_table(:jobs) do
            primary_key :id
            String :name

        end
    end

    down do
        drop_table(:kickstarts, :configfiles, :jobs, :users)
    end
end
