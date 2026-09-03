class ActionItemStatusEvent < ApplicationRecord
  belongs_to :action_item
  belongs_to :actor, class_name: "User"

  validates :previous_status, :new_status, presence: true
  validates :previous_status, :new_status, inclusion: { in: ActionItem::STATUSES }
  validates :comment, presence: true, length: { maximum: ActionItem::STATUS_COMMENT_MAX }
end
