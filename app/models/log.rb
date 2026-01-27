class Log < ApplicationRecord
  serialize :tasks, coder: JSON
  serialize :credits, coder: JSON
end
