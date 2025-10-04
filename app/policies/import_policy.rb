class ImportPolicy < ApplicationPolicy
  def new?
    user&.superuser?
  end

  def create?
    user&.superuser?
  end
end
