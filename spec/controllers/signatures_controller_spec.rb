require 'spec_helper'

describe SignaturesController do
  describe "POST 'begin_authenticating'" do
    before do
      @citizen_id = 6
      @am_success_url = "http://foo.bar"
      @am_failure_url = "http://foo.bar/fail"
      ENV["hmac_key"] = "siikret"
      ENV["SECRET_Alandsbankentesti"] = "bank_secret"
      
      message = {
        idea_id: 5,
        idea_title: "a title",
        idea_date: "2012-06-21",
        citizen_id: @citizen_id,
        accept_publicity: "normal",
        accept_science: true,
        accept_non_eu_server: true,
        accept_general: true,
        idea_mac: "hash"
      }
      options = {
        success_url: @am_success_url,
        failure_url: @am_failure_url,
        service: "Alandsbanken testi"
      }
      
      @params = { message: message, options: options }
      @params[:hmac] = Signing::HmacSha256.sign_array ENV["hmac_key"], message.merge(options).values
    end

    it "assigns the newly created Signature as @signature" do
      post :begin_authenticating, @params
      assigns(:signature).should_not be nil
      assigns(:signature).new_record?.should be_false
    end

    it "renders the select_provider view" do
      post :begin_authenticating, @params
      response.should render_template("begin_authenticating")
    end

    it "assigns citizen_id to a session" do
      post :begin_authenticating, @params
      session[:current_citizen_id].should == @citizen_id
    end

    it "assigns am_success_url to a session" do
      post :begin_authenticating, @params
      session[:am_success_url].should == @am_success_url
    end

    it "assigns am_failure_url to a session" do
      post :begin_authenticating, @params
      session[:am_failure_url].should == @am_failure_url
    end

    it "shows 403 error page if the HMAC does not match" do
      @params[:hmac] = "foobar"
      post :begin_authenticating, @params
      response.body.should include("Invalid MAC")
      response.status.should == 403
    end
  end

  describe "GET 'returning'" do
    describe "with valid arguments" do
      before do
        @signature = FactoryGirl.create :signature, first_names: "John", last_name: "Doe"
        session[:current_citizen_id] = @signature.citizen_id
        @parameters = {id: @signature.id, servicename: "foobar", B02K_CUSTID: "100785-0352", B02K_CUSTNAME: "John Herman Doe"}
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
        @signature = FactoryGirl.create :signature, first_names: "John", last_name: "Doe"
        @parameters = {id: @signature.id, servicename: "foobar", B02K_CUSTID: "100785-0352", B02K_CUSTNAME: "John Herman Doe"}
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
        @signature = FactoryGirl.create :signature, first_names: "John", last_name: "Doe"
        session[:current_citizen_id] = @signature.citizen_id
        session[:am_success_url] = "http://foo.bar"
        @signature.authenticate "Doe John Herman", "1980-03-03"
        @parameters = {id: @signature.id, signature:
          {first_names: "John Herman", last_name: "Doe", vow: true, occupancy_county: "Forssa"}}
      end

      it "assigns the requested Signature as @signature" do
        put :finalize_signing, @parameters
        assigns(:signature).should == @signature
      end

      it "redirects to AM success URL" do
        put :finalize_signing, @parameters
        response.should redirect_to "http://foo.bar"
      end
    end

    describe "with invalid arguments" do
      it "redirects to AM success URL" do
        signature = FactoryGirl.create :signature, first_names: "John", last_name: "Doe"
        session[:current_citizen_id] = signature.citizen_id
        signature.authenticate "Doe John Herman", "1980-03-03"
        parameters = {id: signature.id, signature: {first_names: "John Herman", last_name: "Doe", vow: true}}

        put :finalize_signing, parameters
        response.should render_template("returning")
      end
    end
  end
end
