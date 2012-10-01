class Signature < ActiveRecord::Base
  extend SignaturesHelper

  VALID_STATES = %w(init returned cancelled rejected authenticated expired signed error_invalid_service error_invalid_return error_expired error_repeated_returning error_previously_signed)
  VALID_ACCEPT_PUBLICITY_VALUES = %w(Immediately Normal)
  TIME_LIMIT_IN_MINUTES = 20

  attr_accessible :first_names, :last_name, :birth_date, :occupancy_county, :vow,
    :accept_general, :accept_non_eu_server, :accept_publicity, :accept_science,
    :idea_id, :citizen_id, :idea_title, :idea_date, :idea_mac, :service

  validates :idea_id, numericality: { only_integer: true }
  validates :citizen_id, numericality: { only_integer: true }
  validates :idea_title, presence: true
  validates :idea_date, presence: true
  validates :state, :inclusion => { :in => VALID_STATES }, if: "persisted?"
  validates :accept_publicity, :inclusion => { :in => VALID_ACCEPT_PUBLICITY_VALUES }
  validates :accept_general, presence: true, acceptance: {accept: true}
  validates :accept_non_eu_server, presence: true, acceptance: {accept: true}
  validates :accept_science, presence: true
  validates :vow, presence: true, acceptance: {accept: true}, if: "signed?"
  validates :occupancy_county, inclusion: { in: self.municipalities }, if: "signed?"
  validates :first_names, presence: true, if: "names_required?"
  validates :last_name, presence: true, if: "names_required?"
  validates :birth_date, presence: true, if: "authenticated?"
  validates :service, presence: true

  before_create :generate_stamp
  before_create :initialize_state

  def authenticate first_names, last_name, birth_date
    expire unless is_within_time_limit?

    # handles also repeated returning
    raise InvalidSignatureState.new("init", self) unless initial_state?

    self.first_names = first_names
    self.last_name = last_name
    self.birth_date = birth_date
    self.state = "authenticated"
    self.signing_date = DateTime.current.to_date
    save!
  end

  def is_within_time_limit?
    self.created_at >= DateTime.current.advance(minutes: -TIME_LIMIT_IN_MINUTES)
  end

  def authenticated?
    self.state == "authenticated"
  end

  def signed?
    self.state == "signed"
  end

  def self.find_authenticated_by_citizen id, citizen_id
    where(state: "authenticated", id: id, citizen_id: citizen_id).first!
  end

  def self.find_initial_for_citizen id, citizen_id
    where(state: "init", id: id, citizen_id: citizen_id).first!
  end

  def sign first_names, last_name, occupancy_county, vow
    self.first_names = first_names
    self.last_name = last_name
    self.occupancy_county = occupancy_county
    self.vow = vow
    self.state = "signed"
    self.signing_date = DateTime.current.to_date
    self.save
  end

  private

  def names_required?
    %w(signed).include? self.state
  end

  def expire
    Rails.logger.info "Signature #{self.id} expired"
    self.state = "expired"
    save!
    raise SignatureExpired.new(self.id, self.created_at)
  end

  def generate_stamp
    self.stamp    = DateTime.now.strftime("%Y%m%d%H%M%S") + rand(100000).to_s
  end

  def initialize_state
    self.state = "init"
  end

  def initial_state?
    self.state == "init"
  end

  # TO-DO: Maybe needs a validation is a citizen eligible for voting (i.e. over 18 years old)
end
