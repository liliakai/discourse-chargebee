class AddChargebeeEvents < ActiveRecord::Migration
  def change
    create_table :chargebee_events do |t|
      t.json :json_data
    end
  end
end
