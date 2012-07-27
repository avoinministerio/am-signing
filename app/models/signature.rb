class Signature < ActiveRecord::Base
  VALID_STATES = %w(init query returned cancelled rejected authenticated)
  VALID_ACCEPT_PUBLICITY_VALUES = %w(immediately normal)

  attr_accessible :state, :first_names, :last_name, :birth_date, :occupancy_county, :vow,
    :signing_date, :stamp, :accept_general, :accept_non_eu_server, :accept_publicity,
    :accept_science, :idea_id, :citizen_id

  validates :idea_id, numericality: { only_integer: true }
  validates :citizen_id, numericality: { only_integer: true }
  validates :idea_title, presence: true
  validates :idea_date, presence: true
  validates :stamp, presence: true, format: { with: /\A[0-9]{14,20}\Z/ }
  validates :state, :inclusion => { :in => VALID_STATES }
  validates :accept_publicity, :inclusion => { :in => VALID_ACCEPT_PUBLICITY_VALUES }
  validates :accept_general, :acceptance => true
  validates :accept_non_eu_server, :acceptance => true
  validates :accept_science, :acceptance => true

  # TO-DO: Missing validations for occupancy_county, first_names, last_name.
  # Looks like those need to be conditional validations.

  # TO-DO: Set stamp when created a new Signature
  # s.stamp = DateTime.now.strftime("%Y%m%d%H%M%S") + rand(100000).to_s
end