class LogCategoryAssignment < ApplicationRecord
  belongs_to :log
  belongs_to :category
end
