class Story < ApplicationRecord
  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true

  before_validation :generate_slug, on: :create

  def verses
    content["verses"] || []
  end

  private

  def generate_slug
    # Generate from title if available, otherwise will need to be set manually
    self.slug ||= title.parameterize if title.present?
  end
end
