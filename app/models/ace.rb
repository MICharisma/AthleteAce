class Ace < ApplicationRecord
  class AccountSuspended < StandardError; end
  class GoogleAuthenticationError < StandardError; end

  class PostingMuted < StandardError
    attr_reader :mute

    def initialize(mute)
      @mute = mute
      super("Posting is paused until #{mute.ends_at.utc.iso8601}. #{mute.reason}")
    end
  end
  THEMES = %w[light dark system].freeze
  AVATAR_COLORS = { "Umber" => "#7A4B2A", "Harbor" => "#365A78", "Forest" => "#32634A",
    "Plum" => "#704267", "Slate" => "#485569", "Rust" => "#93452F" }.freeze
  RESERVED_USERNAMES = %w[admin administrator moderator athleteace athlete_ace support system staff help rizz micharisma].freeze

  attr_accessor :password_digest_supplied

  normalizes :time_zone, with: ->(value) { value.presence }
  normalizes :username, with: ->(value) { value.strip.downcase.presence }
  normalizes :display_name, with: ->(value) { value.strip }
  validates :theme, inclusion: { in: THEMES }
  validates :username, presence: true, if: -> { new_record? || username_changed? || validation_context == :profile }
  validates :username, length: { in: 3..24 }, format: { with: /\A[a-z0-9_]+\z/, message: "can only contain letters, numbers, and underscores" },
    uniqueness: { case_sensitive: false }, allow_nil: true
  validates :username, exclusion: { in: RESERVED_USERNAMES }, allow_nil: true, if: -> { new_record? || username_changed? }
  validates :display_name, presence: true, length: { maximum: 60 }, if: -> { username.present? }
  validates :avatar_color, inclusion: { in: AVATAR_COLORS.values }
  validates :google_uid, uniqueness: true, length: { maximum: 255 }, allow_nil: true
  validate :keep_username
  before_destroy :keep_active_admin, prepend: true

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :trackable, :confirmable, :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_one :credit_account, dependent: :restrict_with_error
  has_many :stripe_purchases, dependent: :restrict_with_error
  has_many :shout_outs, foreign_key: :created_by_id, dependent: :restrict_with_error
  has_many :shout_out_drafts, dependent: :destroy
  include Engagements::Engager
  has_many :follows, foreign_key: :actor_id, inverse_of: :ace
  has_many :goals, dependent: :destroy
  has_many :active_goals, -> { Goal.unfinished }, class_name: "Goal"
  has_many :quests, through: :goals
  has_many :ratings, dependent: :destroy
  has_many :rating_revisions, dependent: :delete_all
  has_many :game_attempts, dependent: :destroy
  has_many :game_rounds, dependent: :destroy
  has_many :created_quests, class_name: "Quest", foreign_key: :created_by_id, inverse_of: :created_by, dependent: :nullify
  has_many :practice_reviews, dependent: :destroy
  has_many :entered_attestations, class_name: "Attestation", foreign_key: :entered_by_id,
    inverse_of: :entered_by, dependent: :nullify
  has_many :warnings, class_name: "PostingWarning"
  has_many :mutes
  has_one :active_rizz_binding, -> { active }, class_name: "AceRizzBinding"
  has_many :rizz_bindings, class_name: "AceRizzBinding", dependent: :destroy
  has_many :moderator_notes
  validates :time_zone, inclusion: { in: ActiveSupport::TimeZone.all.map(&:name) }, allow_nil: true

  def self.from_google(auth)
    uid = auth&.[]("uid").to_s
    email = auth&.dig("info", "email").to_s.strip.downcase
    unless auth&.[]("provider") == "google_oauth2" && auth.dig("info", "email_verified") == true && uid.present? && email.present?
      raise GoogleAuthenticationError, "Google could not verify your email address. Please try another sign-in method."
    end

    transaction do
      ace = lock.find_by(google_uid: uid) || lock.find_by(email: email)
      if ace
        raise GoogleAuthenticationError, "Your account is suspended. Contact support for help." if ace.suspended?
        if ace.google_uid.present? && ace.google_uid != uid
          raise GoogleAuthenticationError, "This account is linked to a different Google account. Please sign in with your email and password."
        end
        ace.google_uid = uid
        ace.skip_confirmation!
        ace.save! if ace.changed?
        ace
      else
        ace = new(email: email, google_uid: uid, display_name: auth.dig("info", "name").to_s.first(60), password: Devise.friendly_token(32))
        ace.skip_confirmation!
        ace
      end
    end
  rescue ActiveRecord::RecordNotUnique
    raise GoogleAuthenticationError, "Your Google account could not be linked. Please try signing in again."
  end

  # A confirmed Ace whose password was chosen earlier and is held only as a bcrypt digest.
  def self.build_with_password_digest(digest, **attributes)
    new(attributes).tap do |ace|
      ace.encrypted_password = digest
      ace.password_digest_supplied = true
      ace.skip_confirmation!
    end
  end

  def play_time_zone
    ActiveSupport::TimeZone[time_zone.to_s] || Time.zone
  end

  def role
    admin? ? "admin" : moderator? ? "moderator" : "fan"
  end

  def suspended?
    suspended_at.present?
  end

  def active_for_authentication?
    super && !suspended?
  end

  def inactive_message
    suspended? ? :suspended : super
  end

  def authenticatable_salt
    session_version.positive? ? "#{super}:#{session_version}" : super
  end

  def can_moderate?
    !suspended? && (admin? || moderator?)
  end

  def active_posting_mute
    mutes.active.order(ends_at: :desc, id: :desc).first
  end

  def ensure_posting_access!
    raise AccountSuspended if suspended?
    mute = active_posting_mute
    raise PostingMuted, mute if mute
  end

  def with_posting_access(&block)
    with_lock(requires_new: true) do
      ensure_posting_access!
      block.call
    end
  end

  def handle
    "@#{username}" if username.present?
  end

  def public_name
    display_name.presence || handle || "Ace"
  end

  def initials
    name = display_name.presence || username || "Ace"
    name.split.first(2).map { |part| part.first }.join.upcase
  end

  def adopt_quest(quest)
    goals.find_or_create_by(quest: quest)
  end

  def abandon_quest(quest)
    goals.where(quest: quest).destroy_all
  end

  # Rating methods (RatingService.replace records new ratings)

  # Get all ratings for a specific entity
  # @param rated [Object] The entity to get ratings for
  # @return [ActiveRecord::Relation] The ratings for the entity
  def ratings_for(rated)
    ratings.where(rated: rated, archived: false)
  end

  # Get the rating for a specific entity on a specific spectrum
  # @param rated [Object] The entity to get the rating for
  # @param spectrum [Spectrum] The spectrum to get the rating on
  # @return [Rating, nil] The rating or nil if not rated
  def rating_for(rated, spectrum)
    ratings.find_by(rated: rated, spectrum: spectrum, archived: false)
  end

  # Check if the ace has rated an entity on a spectrum
  # @param rated [Object] The entity to check
  # @param spectrum [Spectrum] The spectrum to check
  # @return [Boolean] Whether the ace has rated the entity on the spectrum
  def rated?(rated, spectrum)
    ratings.active.exists?(rated: rated, spectrum: spectrum)
  end

  protected

  def password_required?
    !password_digest_supplied && super
  end

  private

  def keep_active_admin
    self.class.connection.execute("SELECT pg_advisory_xact_lock(194191, 1)")
    lock!
    if admin? && !suspended? && !self.class.where(admin: true, suspended_at: nil).where.not(confirmed_at: nil).where.not(id: id).exists?
      errors.add :base, :last_active_admin, message: "Keep at least one active admin."
      throw :abort
    end
  end

  def keep_username
    errors.add :username, "cannot be changed" if username_in_database.present? && will_save_change_to_username?
  end
end
