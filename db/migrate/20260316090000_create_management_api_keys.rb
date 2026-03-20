# frozen_string_literal: true

class CreateManagementAPIKeys < ActiveRecord::Migration[7.1]

  def change
    create_table :management_api_keys do |t|
      t.integer :user_id, null: false
      t.string :uuid, null: false
      t.string :name, null: false
      t.string :key_digest, null: false
      t.datetime :last_used_at
      t.datetime :revoked_at
      t.timestamps
    end

    add_index :management_api_keys, :uuid, unique: true
    add_index :management_api_keys, :key_digest, unique: true
    add_index :management_api_keys, :user_id
  end

end
