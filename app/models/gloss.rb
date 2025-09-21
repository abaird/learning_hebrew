class Gloss < ApplicationRecord
  belongs_to :word

  validates :text, presence: true
end
