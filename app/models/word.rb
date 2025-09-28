class Word < ApplicationRecord
  has_many :deck_words, dependent: :destroy
  has_many :decks, through: :deck_words
  has_many :glosses, dependent: :destroy

  validates :representation, presence: true
  validates :part_of_speech, presence: true
end
