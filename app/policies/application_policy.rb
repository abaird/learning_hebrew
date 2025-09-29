class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  def index?
    user.present?
  end

  def show?
    user.present?
  end

  def create?
    user&.superuser? || false
  end

  def new?
    create?
  end

  def update?
    user&.superuser? || false
  end

  def edit?
    update?
  end

  def destroy?
    user&.superuser? || false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise Pundit::NotDefinedError, "Cannot resolve #{@scope.name}"
    end

    private

    attr_reader :user, :scope
  end
end
