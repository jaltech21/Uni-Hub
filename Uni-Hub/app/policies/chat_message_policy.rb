# Policy for ChatMessage authorization
class ChatMessagePolicy < ApplicationPolicy
  # All authenticated users can view their conversations
  def index?
    true
  end

  def show?
    # Users can view conversations they're part of
    record.sender == user || record.recipient == user
  end

  def create?
    # All authenticated users can send messages
    true
  end

  def destroy?
    # Users can only delete their own sent messages
    record.sender == user
  end

  # Scope for filtering messages user has access to
  class Scope < Scope
    def resolve
      # Return messages where user is either sender or recipient
      scope.where('sender_id = ? OR recipient_id = ?', user.id, user.id)
    end
  end
end
