class AdminUser < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, 
         :recoverable, :rememberable, :validatable

    # Ransack requires explicit allowlisting of searchable attributes.
    # Keep this list minimal and avoid sensitive fields like encrypted_password
    # or reset tokens.
    def self.ransackable_attributes(auth_object = nil)
      %w[id email created_at updated_at].freeze
    end

    # No associations are searchable by default for AdminUser.
    def self.ransackable_associations(auth_object = nil)
      [].freeze
    end
end
