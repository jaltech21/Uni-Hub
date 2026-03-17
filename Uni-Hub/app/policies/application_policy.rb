# Base policy class for all policies
# Provides default rules and helper methods for department-based authorization
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  # Scope class for filtering records based on user permissions
  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "You must define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end

  protected

  # Helper: Check if user is an admin or super admin
  def admin?
    user.admin? || user.super_admin?
  end

  # Helper: Check if user can access a specific department
  def can_access_department?(department)
    return true if admin?
    return false if department.nil?
    
    user.can_access_department?(department)
  end

  # Helper: Check if user owns the record
  def owner?
    record.respond_to?(:user) && record.user == user
  end
end
