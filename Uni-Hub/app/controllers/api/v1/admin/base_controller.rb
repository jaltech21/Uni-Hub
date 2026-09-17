module Api
  module V1
    module Admin
      class BaseController < ::Api::V1::BaseController
        before_action :require_admin!

        private

        def require_admin!
          return if current_user.admin?
          render_forbidden
        end
      end
    end
  end
end