# UserHistory stores information about actions that users have taken,
# like deleting users, changing site settings, dimissing notifications, etc.
# Use other classes, like StaffActionLogger, to log records to this table.
class UserHistory < ActiveRecord::Base
  belongs_to :acting_user, class_name: 'User'
  belongs_to :target_user, class_name: 'User'

  belongs_to :post
  belongs_to :topic

  validates_presence_of :action

  scope :only_staff_actions, ->{ where("action IN (?)", UserHistory.staff_action_ids) }

  before_save :set_admin_only

  def self.actions
    @actions ||= Enum.new(:delete_user,
                          :change_trust_level,
                          :change_site_setting,
                          :change_site_customization,
                          :delete_site_customization,
                          :checked_for_custom_avatar, # not used anymore
                          :notified_about_avatar,
                          :notified_about_sequential_replies,
                          :notified_about_dominating_topic,
                          :suspend_user,
                          :unsuspend_user,
                          :facebook_no_email,
                          :grant_badge,
                          :revoke_badge,
                          :auto_trust_level_change,
                          :check_email,
                          :delete_post,
                          :delete_topic,
                          :impersonate,
                          :roll_up,
                          :change_username,
                          :custom,
                          :custom_staff,
                          :anonymize_user)
  end

  # Staff actions is a subset of all actions, used to audit actions taken by staff users.
  def self.staff_actions
    @staff_actions ||= [:delete_user,
                        :change_trust_level,
                        :change_site_setting,
                        :change_site_customization,
                        :delete_site_customization,
                        :suspend_user,
                        :unsuspend_user,
                        :grant_badge,
                        :revoke_badge,
                        :check_email,
                        :delete_post,
                        :delete_topic,
                        :impersonate,
                        :roll_up,
                        :change_username,
                        :custom_staff,
                        :anonymize_user]
  end

  def self.staff_action_ids
    @staff_action_ids ||= staff_actions.map { |a| actions[a] }
  end

  def self.admin_only_action_ids
    @admin_only_action_ids ||= [actions[:change_site_setting]]
  end

  def self.with_filters(filters)
    query = self
    query = query.where(action: filters[:action_id]) if filters[:action_id].present?
    query = query.where(custom_type: filters[:custom_type]) if filters[:custom_type].present?

    [:acting_user, :target_user].each do |key|
      if filters[key] and obj_id = User.where(username_lower: filters[key].downcase).pluck(:id)
        query = query.where("#{key}_id = ?", obj_id)
      end
    end
    query = query.where("subject = ?", filters[:subject]) if filters[:subject]
    query
  end

  def self.for(user, action_type)
    self.where(target_user_id: user.id, action: UserHistory.actions[action_type])
  end

  def self.exists_for_user?(user, action_type, opts=nil)
    opts = opts || {}
    result = self.where(target_user_id: user.id, action: UserHistory.actions[action_type])
    result = result.where(topic_id: opts[:topic_id]) if opts[:topic_id]
    result.exists?
  end

  def self.staff_filters
    [:action_id, :custom_type, :acting_user, :target_user, :subject]
  end

  def self.staff_action_records(viewer, opts=nil)
    opts ||= {}
    query = self.with_filters(opts.slice(*staff_filters)).only_staff_actions.limit(200).order('id DESC').includes(:acting_user, :target_user)
    query = query.where(admin_only: false) unless viewer && viewer.admin?
    query
  end


  def set_admin_only
    self.admin_only = UserHistory.admin_only_action_ids.include?(self.action)
    self
  end

  def new_value_is_json?
    [UserHistory.actions[:change_site_customization], UserHistory.actions[:delete_site_customization]].include?(action)
  end

  def previous_value_is_json?
    new_value_is_json?
  end
end

# == Schema Information
#
# Table name: user_histories
#
#  id             :integer          not null, primary key
#  action         :integer          not null
#  acting_user_id :integer
#  target_user_id :integer
#  details        :text
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  context        :string(255)
#  ip_address     :string(255)
#  email          :string(255)
#  subject        :text
#  previous_value :text
#  new_value      :text
#  topic_id       :integer
#  admin_only     :boolean          default(FALSE)
#  post_id        :integer
#
# Indexes
#
#  index_user_histories_on_acting_user_id_and_action_and_id  (acting_user_id,action,id)
#  index_user_histories_on_action_and_id                     (action,id)
#  index_user_histories_on_subject_and_id                    (subject,id)
#  index_user_histories_on_target_user_id_and_id             (target_user_id,id)
#
