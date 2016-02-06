class AddChargebeeIdToInvites < ActiveRecord::Migration
  def change
    add_column :invites, :chargebee_id, :string
  end
end
