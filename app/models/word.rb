class Word < ApplicationRecord
  belongs_to :deck
  has_many :glosses, dependent: :destroy

  validates :representation, presence: true
  validates :part_of_speech, presence: true
end