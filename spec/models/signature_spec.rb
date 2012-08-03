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
    it { should_not be_accessible(:signing_date) }
    it { should_not be_accessible(:stamp) }
    it { should be_accessible(:accept_publicity) }

    describe "Validations" do
      it { should validate_numericality_of(:citizen_id).only_integer }
      it { should validate_numericality_of(:idea_id).only_integer }
      it { should validate_presence_of(:idea_title) }

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
    it "should be generated when the Signature is created" do
      s = Signature.new
      s.save validate: false
      s.stamp.should match(/\A[0-9]{14,20}\Z/)
    end
  end

  describe "state" do
    it "should set as init when the Signature is created" do
      s = Signature.new
      s.save validate: false
      s.state.should == "init"
    end
  end

  describe "authenticate" do
    before do
      @birth_date = 20.years.ago
      @first_names = "John Herman"
      @last_name = "Doe"
      @signature = FactoryGirl.create :signature
    end

    it "sets state to authenticated" do
      @signature.authenticate @first_names, @last_name, @birth_date
      @signature.state.should == "authenticated"
    end

    it "set signing_date to today" do
      @signature.authenticate @first_names, @last_name, @birth_date
      @signature.signing_date.should == DateTime.current.to_date
    end

    it "raises an error if validation fails" do
      lambda { @signature.authenticate @first_names, @last_name, nil }.should raise_error ActiveRecord::RecordInvalid
    end

    it "expires the Signature if it is created at more than 20 minutes ago" do
      signature = FactoryGirl.create :signature, created_at: DateTime.current.advance(minutes: -21)
      lambda { signature.authenticate @first_names, @last_name, @birth_date }.should raise_error SignatureExpired
      signature.state.should == "expired"
    end
  end

  describe "is_within_time_limit?" do
    it "true if Signature is created at less than 20 minutes ago" do
      signature = FactoryGirl.create :signature
      signature.is_within_time_limit?.should be_true
    end

    it "flase if Signature is created at more than 20 minutes ago" do
      signature = FactoryGirl.create :signature, created_at: DateTime.current.advance(minutes: -21)
      signature.is_within_time_limit?.should be_false
    end
  end
end
