class Sum < ApplicationRecord
  validates :balance, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
