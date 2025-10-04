class PartOfSpeechCategory < ApplicationRecord
  has_many :words

  validates :name, presence: true, uniqueness: true
  validates :abbrev, presence: true, uniqueness: true
end
