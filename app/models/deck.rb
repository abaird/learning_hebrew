class Deck < ApplicationRecord
  belongs_to :user
  has_many :deck_words, dependent: :destroy
  has_many :words, through: :deck_words

  validates :name, presence: true
end
