class Deck < ApplicationRecord
  belongs_to :user
  has_many :words, dependent: :destroy

end
