class DeckWord < ApplicationRecord
  belongs_to :deck
  belongs_to :word
  validates :deck_id, uniqueness: { scope: :word_id }
end