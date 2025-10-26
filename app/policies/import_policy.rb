class ImportPolicy < ApplicationPolicy
  def new?
    user&.superuser?
  end

  def create?
    user&.superuser?
  end

  def import_story?
    user&.superuser?
  end
end
