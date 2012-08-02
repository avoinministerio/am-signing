class CreateSignature < ActiveRecord::Migration
  def change
    create_table :signatures do |t|
      t.integer     :citizen_id
      t.integer     :idea_id
      t.string      :idea_title
      t.date        :idea_date
      t.string      :idea_mac
      t.string      :first_names
      t.string      :last_name
      t.date        :birth_date
      t.string      :occupancy_county
      t.boolean     :vow
      t.date        :signing_date
      t.string      :state
      t.string      :stamp

      t.boolean     :accept_general
      t.boolean     :accept_non_eu_server
      t.boolean     :accept_science
      t.string      :accept_publicity

      t.timestamps
    end
  end
end
