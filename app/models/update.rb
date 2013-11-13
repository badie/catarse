class Update < ActiveRecord::Base
  extend CatarseAutoHtml

  schema_associations
  has_many :notifications, dependent: :destroy
  validates_presence_of :user_id, :project_id, :comment, :comment_html
  before_save -> {self.comment = comment.gsub(/^\s+/, "")}

  catarse_auto_html_for field: :comment, video_width: 560, video_height: 340

  scope :visible_to, ->(user) {
    user_id = (user.present? ? user.id : nil)

    return  if user.present? && user.admin?

    where(
      "not exclusive
      or exists(select true from backers b where b.user_id = :user_id and b.state = 'confirmed' and b.project_id = updates.project_id)
      or exists(select true from projects p where p.user_id = :user_id and p.id = updates.project_id)",
      { user_id: user_id }
    )
  }

  def update_number
    self.project.updates.where('id <= ?', self.id).count
  end

  def email_comment_html
    auto_html(comment) do
      html_escape map: {
        '&' => '&amp;',
        '>' => '&gt;',
        '<' => '&lt;',
        '"' => '"'
      }
      email_image width: 513
      redcloth target: :_blank
      link target: :_blank
    end
  end

  def notify_backers
    project.subscribed_users.each do |user|
      Rails.logger.info "[User #{user.id}] - Creating notification for #{user.name}"
      Notification.notify_once(
        :updates, 
        user,
        {update_id: self.id, user_id: user.id},
        {
          project: project,
          project_update: self,
          origin_email: project.user.email,
          origin_name: project.user.display_name
        }
      )
    end
  end

end
