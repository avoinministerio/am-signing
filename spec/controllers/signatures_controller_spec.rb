require 'spec_helper'

describe SignaturesController do
  describe "POST select_provider" do
    before do
      @citizen_id = 6
      @am_success_url = "http://foo.bar"
      @params = { message: { idea_title: "a title", idea_date: "2012-06-21", idea_id: 5, citizen_id: @citizen_id,
        accept_publicity: "normal", accept_science: true, accept_non_eu_server: true, accept_general: true },
        success_url: @am_success_url }
    end

    it "assigns the newly created Signature as @signature" do
      post :select_provider, @params
      assigns(:signature).should_not be nil
      assigns(:signature).new_record?.should be_false
    end

    it "renders the select_provider view" do
      post :select_provider, @params
      response.should render_template("select_provider")
    end

    it "assigns citizen_id to a session" do
      post :select_provider, @params
      session[:current_citizen_id].should == @citizen_id
    end

    it "assigns am_success_url to a session" do
      post :select_provider, @params
      session[:am_success_url].should == @am_success_url
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
        response.should redirect_to "http://foo.bar"
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
