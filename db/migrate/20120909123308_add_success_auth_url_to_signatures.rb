class AddSuccessAuthUrlToSignatures < ActiveRecord::Migration
  def up
    add_column    :signatures, :success_auth_url, :string
  end
  def down
    remove_column :signatures, :success_auth_url
  end
end
