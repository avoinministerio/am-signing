class Signature < ActiveRecord::Base
  extend SignaturesHelper

  VALID_STATES = %w(init returned cancelled rejected authenticated expired signed)
  VALID_ACCEPT_PUBLICITY_VALUES = %w(immediately normal)
  TIME_LIMIT_IN_MINUTES = 20

  attr_accessible :first_names, :last_name, :birth_date, :occupancy_county, :vow,
    :accept_general, :accept_non_eu_server, :accept_publicity, :accept_science,
    :idea_id, :citizen_id, :idea_title, :idea_date, :idea_mac

  validates :idea_id, numericality: { only_integer: true }
  validates :citizen_id, numericality: { only_integer: true }
  validates :idea_title, presence: true
  validates :idea_date, presence: true
  validates :state, :inclusion => { :in => VALID_STATES }, if: "persisted?"
  validates :accept_publicity, :inclusion => { :in => VALID_ACCEPT_PUBLICITY_VALUES }
  validates :accept_general, presence: true, acceptance: {accept: true}
  validates :accept_non_eu_server, presence: true, acceptance: {accept: true}
  validates :accept_science, presence: true, acceptance: {accept: true}
  validates :vow, presence: true, acceptance: {accept: true}, if: "signed?"
  validates :occupancy_county, inclusion: { in: self.municipalities }, if: "signed?"
  validates :first_names, presence: true, if: "names_required?"
  validates :last_name, presence: true, if: "names_required?"
  validates :birth_date, presence: true, if: "authenticated?"

  validate :name_cannot_contain_numbers

  before_create :generate_stamp
  before_create :initialize_state

  def authenticate full_name, birth_date
    expire unless is_within_time_limit?
    raise InvalidSignatureState.new("init", self) unless state == "init"
    
    guess_names full_name, self.last_name, self.first_names

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
    %w(authenticated signed).include? self.state
  end

  def name_cannot_contain_numbers
    errors.add(:first_names, :cannot_contain_numbers) if has_numbers? self.first_names
    errors.add(:last_name, :cannot_contain_numbers) if has_numbers? self.last_name
  end

  def has_numbers? name
    name =~ /\d/
  end

  def expire
    Rails.logger.info "Signature #{self.id} expired"
    self.state = "expired"
    save!
    raise SignatureExpired.new(self.id, self.created_at)
  end

  def generate_stamp
    self.stamp = DateTime.now.strftime("%Y%m%d%H%M%S") + rand(100000).to_s
  end

  def initialize_state
    self.state = "init"
  end

  def guess_names full_name, last_name, first_names
    if m = /^\s*#{last_name}\s*/.match(full_name) # known last name is at the beginning
      first_names = m.post_match
    elsif m = /\s*#{last_name}\s*$/.match(full_name) # known last name is at the end
      first_names = m.pre_match
    end
    self.first_names = first_names
    self.last_name = last_name
  end

  # TO-DO: Maybe needs a validation is a citizen eligible for voting (i.e. over 18 years old)
end
