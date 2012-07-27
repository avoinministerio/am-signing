require 'spec_helper'

describe Signature do
  describe "Attributes" do
    it { should be_accessible(:citizen_id) }
    it { should be_accessible(:idea_id) }
    it { should_not be_accessible(:state) }
    it { should be_accessible(:idea_title) }
    it { should be_accessible(:idea_date) }
    it { should be_accessible(:idea_mac) }
    it { should be_accessible(:first_names) }
    it { should be_accessible(:last_name) }
    it { should be_accessible(:birth_date) }
    it { should be_accessible(:occupancy_county) }
    it { should be_accessible(:vow) }
    it { should be_accessible(:signing_date) }
    it { should_not be_accessible(:stamp) }
    it { should be_accessible(:accept_publicity) }

    describe "Validations" do
      it { should validate_numericality_of(:citizen_id).only_integer }
      it { should validate_numericality_of(:idea_id).only_integer }
      it { should validate_presence_of(:idea_title) }
      it { should_not allow_value("foobar").for(:stamp) }

      describe "state" do
        it "should only allow valid states" do
          Signature::VALID_STATES.each do |s|
            should allow_value(s).for(:state)
          end
        end
        it { should_not allow_value("other").for(:state) }
      end

      describe "accept_publicity" do
        it "should only allow valid values" do
          Signature::VALID_ACCEPT_PUBLICITY_VALUES.each do |s|
            should allow_value(s).for(:accept_publicity)
          end
        end
        it { should_not allow_value("foo").for(:accept_publicity) }
      end
    end
  end

  describe "stamp" do
    it "should be generated before validation when there is no previous stamp" do
      s = Signature.create
      s.stamp.should match(/\A[0-9]{14,20}\Z/)
    end

    it "should not be generated before validation when there is a previous stamp" do
      s = Signature.new
      s.stamp = "foobar"
      s.stamp.should == "foobar"
    end
  end
end
