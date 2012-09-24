#encoding: UTF-8
require 'spec_helper'

describe SignaturesController do
  describe "GET 'begin_authenticating'" do
    
    let(:message) do
      {
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
      }
    end

    before do
      @citizen_id = 6
      @am_success_url = "http://foo.bar"
      @am_failure_url = "http://foo.bar/fail"
      ENV["requestor_secret"] = "siikret"
      ENV["SECRET_Alandsbankentesti"] = "bank_secret"
        
      @params = {
        message: message, 
        options: { success_url: @am_success_url, failure_url: @am_failure_url },
        last_fill_birth_date: "1985-01-06",
        last_fill_occupancy_county: "Helsinki",
        authentication_token: "",
        authenticated_at: "2012-09-10T19:17:46+03:00" }
        #puts SignaturesController.new.send(:requestor_params_as_string, @params)

        @params[:requestor_identifying_mac] = Digest::SHA256.hexdigest(SignaturesController.new.send(:requestor_params_as_string, @params) + "&requestor_secret=#{ENV['requestor_secret']}").upcase 
    end

    it "should return 200" do
      get :begin_authenticating, @params
      response.status.should  == 200
    end

    it "assigns the newly created Signature as @signature" do
      get :begin_authenticating, @params
      assigns(:signature).should_not be nil
      assigns(:signature).new_record?.should be_false
    end

    it "renders the select_provider view" do
      get :begin_authenticating, @params
      response.should render_template("begin_authenticating")
    end

    it "assigns citizen_id to a session" do
      get :begin_authenticating, @params
      session[:current_citizen_id].should == @citizen_id
    end

    it "assigns am_success_url to a session" do
      get :begin_authenticating, @params
      session[:am_success_url].should == @am_success_url
    end

    it "assigns am_failure_url to a session" do
      get :begin_authenticating, @params
      session[:am_failure_url].should == @am_failure_url
    end

    it "shows 403 error page if the HMAC does not match" do
      @params[:requestor_identifying_mac] = "foobar"
      get :begin_authenticating, @params
      response.body.should include("Invalid MAC")
      response.status.should == 403
    end
  end

  describe "GET 'returning'" do
    let(:service) { "Alandsbankentesti" }
    let(:service_with_space)  { "Alandsbanken testi" }

    before do
      ENV["SECRET_Alandsbankentesti"] = "bank_secret"

      # TO-DO: Validating TUPAS message should be extracted from the controller
      controller.stub(:valid_returning?) { true }
    end

    describe "with valid arguments" do
      before do
        @signature = FactoryGirl.create :signature, first_names: "John", last_name: "Doe", service: service_with_space
        session[:current_citizen_id] = @signature.citizen_id
        @parameters = {id: @signature.id, servicename: service, B02K_CUSTID: "100785-0352", B02K_CUSTNAME: "John Herman Doe"}
      end

      it "assigns the requested Signature as @signature" do
        get :returning, @parameters
        assigns(:signature).should == @signature
      end

      it "renders the returning view" do
        get :returning, @parameters
        response.should render_template("returning")
      end
    end

    describe "with invalid arguments" do
      before do
        @signature = FactoryGirl.create :signature, first_names: "John", last_name: "Doe", service: service
        @parameters = {id: @signature.id, servicename: service, B02K_CUSTID: "100785-0352", B02K_CUSTNAME: "John Herman Doe"}
      end

      it "shows 404 error page if the requested Signature doesn't belong to the citizen" do
        session[:current_citizen_id] = @signature.citizen_id + 10
        get :returning, @parameters
        response.body.should include("404")
        response.status.should == 404
      end

      it "shows 403 error page if the requested Signature is expired" do
        signature = FactoryGirl.create :signature, first_names: "John", last_name: "Doe", created_at: DateTime.current.advance(minutes: -21)
        session[:current_citizen_id] = signature.citizen_id
        @parameters[:id] = signature.id
        
        get :returning, @parameters

        response.body.should include("Expired")
        response.status.should == 403
      end
    end
  end

  describe "PUT finalize_signing" do
    describe "with valid arguments" do
      before do
        @signature = FactoryGirl.create :signature
        session[:current_citizen_id] = @signature.citizen_id
        session[:am_success_url] = "http://foo.bar"
        @signature.authenticate "John Herman", "Doe", "1980-03-03"
        @parameters = {id: @signature.id, signature:
          {first_names: "John Herman", last_name: "Doe", vow: true, occupancy_county: "Forssa"}}
      end

      it "assigns the requested Signature as @signature" do
        put :finalize_signing, @parameters
        assigns(:signature).should == @signature
      end

      it "redirects to AM success URL" do
        put :finalize_signing, @parameters
        response.header["Location"].should start_with "http://foo.bar"
        response.status.should == 302
      end
    end

    describe "with invalid arguments" do
      it "redirects to AM success URL" do
        signature = FactoryGirl.create :signature
        session[:current_citizen_id] = signature.citizen_id
        signature.authenticate "John Herman", "Doe", "1980-03-03"
        parameters = {id: signature.id, signature: {first_names: "John Herman", last_name: "Doe", vow: true}}

        put :finalize_signing, parameters
        response.should render_template("returning")
      end
    end
  end
end
