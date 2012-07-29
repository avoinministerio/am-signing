class Signature < ActiveRecord::Base
  VALID_STATES = %w(init returned cancelled rejected authenticated)
  VALID_ACCEPT_PUBLICITY_VALUES = %w(immediately normal)

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
  validates :first_names, presence: true, if: "authenticated?"
  validates :last_name, presence: true, if: "authenticated?"
  validates :birth_date, presence: true, if: "authenticated?"

  before_create :generate_stamp
  before_create :initialize_state

  def authenticate first_names, last_name, birth_date
    self.first_names = first_names
    self.last_name = last_name
    self.birth_date = birth_date
    self.state = "authenticated"
    self.signing_date = DateTime.current.to_date
    save!
  end

  def authenticated?
    self.state == "authenticated"
  end

  private

  def generate_stamp
    self.stamp = DateTime.now.strftime("%Y%m%d%H%M%S") + rand(100000).to_s
  end

  def initialize_state
    self.state = "init"
  end

  # TO-DO: Missing validation for occupancy_county. When is this value required?

  # TO-DO: Maybe needs a validation is a citizen eligible for voting (i.e. over 18 years old)
end
