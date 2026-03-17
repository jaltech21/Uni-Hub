ActiveAdmin.register User do

  # See permitted parameters documentation:
  # https://github.com/activeadmin/activeadmin/blob/master/docs/2-resource-customization.md#setting-up-strong-parameters
  #
  # Uncomment all parameters which should be permitted for assignment
  #
  # permit_params :email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at, :role
  #
  # or
  #
  # permit_params do
  #   permitted = [:email, :encrypted_password, :reset_password_token, :reset_password_sent_at, :remember_created_at, :role]
  #   permitted << :other if params[:action] == 'create' && current_user.admin?
  #   permitted
  # end

  # app/admin/users.rb
  permit_params :email, :role

  filter :email
  filter :role, as: :select, collection: ['student', 'teacher'] # Filter by the custom role
  filter :created_at
  filter :updated_at

  index do
    selectable_column
    id_column
    column :email
    column :role
    column :created_at
    actions
  end

  form do |f|
    f.inputs do
      f.input :email
      f.input :role, as: :select, collection: ['student', 'teacher']
    end
    f.actions
  end
  
end
