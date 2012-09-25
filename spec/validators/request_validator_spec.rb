#encoding: UTF-8

require 'spec_helper'

describe 'RequestValidator' do

  before(:all) do
    ENV['requestor_secret'] = 'siikret'
  end

  describe '#valid?' do
    let(:valid_signature) { '7E9603B54930F841F7DB5C48ADF61F69A750C319451DC8D8A007EA3C1832BE7A' }
    let(:invalid_signature) { '00C843B753F2B2B8105873C6A570C2DF5B1C580FA5819629149AFD8FE5DB0921' }

    let(:valid_params) do
      {
        message: {
          citizen_id: 6,
          first_names: "Matti Petteri",
          last_name: "Nykänen",
          accept_publicity: "Normal",
          accept_science: "true",
          accept_non_eu_server: "true",
          accept_general: "true",
          service: "Alandsbanken testi",
          idea_id: 5,
          idea_title: "a title",
          idea_date: "2012-09-05T19:17:46+03:00",
          idea_mac: "23151216EAB9DE9C6647DE9BC2A03915"
        },
        options: {
          success_url: 'sfdfsd',
          failure_url: 'sfdsfd'
        },
        last_fill_birth_date: "1985-01-06",
        last_fill_occupancy_county: "Helsinki",
        authentication_token: "",
        authenticated_at: "2012-09-10T19:17:46+03:00"
      }
    end

    let(:invalid_params) do
      {
        message: {
          idea_id: 5,
          idea_title: "a title",
          idea_date: "2012-09-05T19:17:46+03:00",
          idea_mac: "23151216EAB9DE9C6647DE9BC2A03915",
          citizen_id: 6,
          first_names: "Matti Petteri",
          last_name: "Nykänen",
          accept_publicity: "Normal",
          accept_science: "true",
          accept_non_eu_server: "true",
          accept_general: "true",
          service: "Alandsbanken testi"
        },
        options: {
          success_url: 'sfdfsd',
          failure_url: 'sfdsfd'
        },
        last_fill_birth_date: "1985-01-06",
        last_fill_occupancy_county: "Helsinki",
        authentication_token: "",
        # drop authenticated_at
      }
    end

    it "return true if params and signature are valid" do
      RequestValidator.valid?(valid_params, valid_signature).should be_true
    end

    it "return false if params are valid but signature invalid" do
      RequestValidator.valid?(invalid_params, valid_signature).should be_false
    end

    it "return false if params are invalid and signature invalid" do
      RequestValidator.valid?(invalid_params, invalid_signature).should be_false
    end

  end
end