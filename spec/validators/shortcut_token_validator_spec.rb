#encoding: UTF-8

require 'spec_helper'

describe "ShortcutTokenValidator" do
  before(:all) do
    time = DateTime.parse('2012-09-05T19:17:46+03:00')
    Timecop.travel(time)
    ENV['authentication_token_secret'] = 'jaska'
  end

  after(:all) do
    Timecop.return
  end

  let(:valid_birth_date) { '1982-02-21' }
  let(:valid_authenticated_at) { '2012-09-05T19:17:46+03:00' }
  let(:valid_authentication_token) { 'D7B6F8223BE2ABCFA6E429056CDE2E3FE755732C8BFC4D882F3468D863E1FA45'  }

  describe "#valid?" do
    it "returns true with valid birth date, valid authentication token and authenticated at less than 2 minutes ago" do
      ShortcutTokenValidator.valid?(valid_birth_date, valid_authenticated_at, valid_authentication_token).should be_true
    end

    it "returns false with invalid birth date" do
      ShortcutTokenValidator.valid?('sdfsdfsdf', valid_authenticated_at, valid_authentication_token).should be_false
    end

    it "returns false with invalid authenticated at time" do
      ShortcutTokenValidator.valid?(valid_birth_date, 'sfdsfdfdsfsdfds', valid_authentication_token).should be_false
    end

    it "returns false with invalid authentication token" do
      ShortcutTokenValidator.valid?(valid_birth_date, valid_authenticated_at, 'sdfsdfsdfsdf').should be_false
    end
  end
end
