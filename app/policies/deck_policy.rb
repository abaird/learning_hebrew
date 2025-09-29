class DeckPolicy < ApplicationPolicy
  def create?
    user.present?  # All users can create decks
  end

  def update?
    user.present? && (user.superuser? || record.user == user)
  end

  def destroy?
    update?  # Same permissions as update
  end
end
