class AddChargebeeIdToUsers < ActiveRecord::Migration
  def change
    add_column :users, :chargebee_id, :string
  end
end
