#encoding: UTF-8

require 'signatures_controller_helpers'

class SignaturesController < ApplicationController

  include SignaturesControllerHelpers

  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  rescue_from SignatureExpired,             :with => :signature_expired
  rescue_from InvalidMac,                   :with => :invalid_mac

  respond_to :html

  # Start signing an idea
  def begin_authenticating
    validate_requestor!
    validate_begin_authenticating_parameters!

    # TODO: Could be checked that user has not signed already, but it is not required

    @signature = Signature.create! params[:message]

    session[:current_citizen_id]    = @signature.citizen_id
    session[:am_success_url]        = params[:options][:success_url]
    session[:am_failure_url]        = params[:options][:failure_url]
    
    if params[:message] and (params[:message][:service] == "shortcut")
      birth_date, authenticated_at, authentication_token = params[:last_fill_birth_date], params[:authenticated_at], params[:authentication_token]
      if( birth_date and parse_datetime(birth_date) and 
          authenticated_at and parse_datetime(authenticated_at) and 
          authentication_token and authentication_token =~ /^[0-9A-F]+$/ and
          valid_authentication_token?(birth_date, authenticated_at, authentication_token) and 
          authentication_age(authenticated_at) < minutes(2) )
        return shortcut_returning
      else
        redirect_to(session[:am_failure_url])
        return
      end
    end

    if not tupas_services.find {|ts| ts[:name] == params[:message][:service]}
      # call with incorrect service yields failure
      # this is intentional as service is omitted in case of previous authentication still valid
      redirect_to(session[:am_failure_url])
      return
    end

    @service = find_service params[:message][:service]
    set_signature_specific_values @signature, @service
    set_mac @service

    render
  end


  def returning
    @signature = Signature.find_initial_for_citizen(params[:id], current_citizen_id)
    service_name = params[:servicename]

    if not same_service?(@signature, service_name)
      Rails.logger.info "Trying to return from #{service_name} which is wrong service as #{@signature.service} is required"
      @signature.state = "error_invalid_service"
      @signature.save!
      raise "Invalid service"
    elsif not valid_returning?(@signature, service_name)
      Rails.logger.info "Invalid return from #{service_name} for signature.id=#{@signature.id}"
      @signature.state = "error_invalid_return"
      @signature.save!
      raise InvalidMac.new
    end

    # this is the point where cost incurred, thus we need to make sure the main app will do the deduction
    signal_successful_authentication

    if check_previously_signed(current_citizen_id, @signature.idea_id)
      Rails.logger.info "Previously current_citizen_id=#{current_citizen_id} has signed @signature.idea_id=#{@signature.idea_id}"
      raise "Previously signed"
    end

    birth_date = hetu_to_birth_date(params["B02K_CUSTID"])
    first_names, last_name = guess_names(params["B02K_CUSTNAME"], @signature.first_names, @signature.last_name)

    @signature.authenticate first_names, last_name, birth_date

    Rails.logger.info "All success, authentication ok, storing into session"
    session["authenticated_at"]         = DateTime.now

    respond_with @signature
  end

  def finalize_signing
    @signature = Signature.find_authenticated_by_citizen params[:id], current_citizen_id

    # TODO: and duration since last authentication less that threshold. Validation?
    if @signature.sign params["signature"]["first_names"], params["signature"]["last_name"],
      params["signature"]["occupancy_county"], params["signature"]["vow"]
      other_params = {
        first_names:          @signature.first_names,
        last_name:            @signature.last_name,
        occupancy_county:     @signature.occupancy_county,
        authenticated_at:     session["authenticated_at"],
        birth_date:           @signature.birth_date,
        authentication_token: calculate_authentication_token(@signature.birth_date, session["authenticated_at"]),
      }
      url = session[:am_success_url] + "?" + other_params.map {|name, value| h={}; h[name]=value; h.to_param}.join("&")
      Rails.logger.info(url + "&requestor_secret=#{ENV['requestor_secret']}")
      Rails.logger.info(mac(url + "&requestor_secret=#{ENV['requestor_secret']}"))
      service_provider_mac = mac(url + "&requestor_secret=#{ENV['requestor_secret']}")
      redirect_to(url + "&service_provider_identifying_mac=#{service_provider_mac}")
    else
      render "returning"
    end
  end

  def shortcut_returning
    if check_previously_signed(current_citizen_id, @signature.idea_id)
      Rails.logger.info "error_previously_signed"
      raise "Previously signed"
    end

    @signature.authenticate params["last_fill_first_names"], params["last_fill_last_names"], params["last_fill_birth_date"]
    @signature.occupancy_county = params["last_fill_occupancy_county"]
    @signature.save

    Rails.logger.info "Shortcut success, authentication ok, storing into session"
    session["authenticated_at"]         = params["authenticated_at"]

    render "shortcut_returning"
  end

  def cancelling
    cancel_or_reject("cancelled")
  end

  def rejecting
    cancel_or_reject("rejected")
  end


  private

  # TODO: user would benefit from cancel or reject having some MAC check to be sure 
  # no one is forging the request while person is in the TUPAS service
  def cancel_or_reject(state_update)
    @signature = Signature.find_initial_for_citizen(params[:id], current_citizen_id)

    if not @signature.citizen_id == current_citizen_id
      Rails.logger.info "Trying to return for different user signature"
      raise "Not current_citizen's signature"
    # TODO: it would be great to provide the cancelling with proper validating mac to make sure not even user could forge
    # elsif valid_cancelling?
    #    raise "Invalid cancelling"
    end

    @signature.state = state_update
    @signature.save

    url = session[:am_failure_url]
    redirect_to(url)
  end

  def valid_authentication_token?(birth_date, authenticated_at, authentication_token)
    authentication_token == calculate_authentication_token(birth_date, authenticated_at)
  end

  def calculate_authentication_token(birth_date, authenticated_at)
    authentication_token_secret = ENV['authentication_token_secret'] || ""
    Rails.logger.info("Calculating authentication token")
    Rails.logger.info([birth_date, authenticated_at, authentication_token_secret].inspect)
    mac(birth_date.to_s + authenticated_at.to_s + authentication_token_secret)
  end

  def tupas_services
    services = [
      { vers:       "0001",
        rcvid:      "Elisa testi",
        idtype:     "12",
        name:       "Elisa Mobiilivarmenne testi",
        url:        "https://mtupaspreprod.elisa.fi/tunnistus/signature.cmd",
      },
      { vers:       "0001",
        rcvid:      "Avoinministerio",
        idtype:     "12",
        name:       "Elisa Mobiilivarmenne",
        url:        "https://tunnistuspalvelu.elisa.fi/tunnistus/signature.cmd",
      },
      { vers:       "0002",
        rcvid:      "AABTUPASID",
        idtype:     "02",
        name:       "Alandsbanken testi",
        url:        "https://online.alandsbanken.fi/ebank/auth/initLogin.do",
      },
      { vers:       "0002",
        rcvid:      "ELEKAMINNID",
        idtype:     "02",
        name:       "Alandsbanken",
        url:        "https://online.alandsbanken.fi/ebank/auth/initLogin.do",
      },
      { vers:       "0002",
        rcvid:      "TAPTUPASID",
        idtype:     "02",
        name:       "Tapiola testi",
        url:        "https://pankki.tapiola.fi/service/identify",
      },
      { vers:       "0002",
        rcvid:      "KANNATUSTUPAS12",
        idtype:     "02",
        name:       "Tapiola",
        url:        "https://pankki.tapiola.fi/service/identify",
      },
      { vers:       "0003",
        rcvid:      "024744039900",
        idtype:     "02",
        name:       "Sampo",
        url:        "https://verkkopankki.sampopankki.fi/SP/tupaha/TupahaApp",
      }
    ]
  end

  # This method should be replaced with TUPAS gem by jaakkos
  def find_service name
    service = tupas_services.find { |s| s[:name] == name }
    raise ArgumentError.new("Service not found with name \"#{name}\"") unless service != nil
    
    set_defaults service
    service
  end

  def set_defaults service
    service[:action_id] = "701"
    service[:langcode]  = "FI"
    service[:keyvers]   = "0001"
    service[:alg]       = "03"
  end

  def set_signature_specific_values signature, service
    service[:stamp] = signature.stamp

    server = "http" + (Rails.env == "development" ? "" : "s" ) + "://#{request.host_with_port}"
    Rails.logger.info "Server is #{server}"

    service_name = service_name_to_param(service[:name])
    service[:retlink] = "#{server}/signatures/#{signature.id}/returning/#{service_name}"
    service[:canlink] = "#{server}/signatures/#{signature.id}/cancelling/#{service_name}"
    service[:rejlink] = "#{server}/signatures/#{signature.id}/rejecting/#{service_name}"
  end

  def set_mac service
    secret = service_secret(service[:name])
    keys = [:action_id, :vers, :rcvid, :langcode, :stamp, :idtype, :retlink, :canlink, :rejlink, :keyvers, :alg]
    vals = keys.map{|k| service[k] }
    string = vals.join("&") + "&" + secret + "&"
    Rails.logger.info  "Calculating mac for '#{string}'"
    Rails.logger.info  "Mac is              '#{mac(string)}'"
    service[:mac] = mac(string)
  end

  def service_secret(service_name)
    secret_key = "SECRET_" + service_name.gsub(/\s/, "")

    Rails.logger.info "Using key #{secret_key}"
    secret = ENV[secret_key] || ""

    # TODO: precalc the secret into environment variable, and remove this special handling
    if service_name =~ /^Alandsbanken/ or service_name == "Tapiola"
      secret = secret_to_mac_string(secret)
      Rails.logger.info "Converting secret to #{secret}"
    end

    if secret.blank?
      Rails.logger.error "No SECRET found for #{secret_key}"
      raise Exception.new "No secret found for #{secret_key}"
    end

    secret
  end

  def secret_to_mac_string(secret)
    str = ""
    secret.split(//).each_slice(2){|a| str += a.join("").hex.chr}
    Rails.logger.info(str.inspect)
    str
  end

  def validate_requestor!
    param_string = requestor_params_as_string(params) + "&requestor_secret=#{ENV['requestor_secret']}"
    unless params[:requestor_identifying_mac] == mac(param_string)
      raise InvalidMac.new(params.dup, param_string, mac(param_string), ENV['requestor_secret'])
    end
  end

  def requestor_params_as_string(parameters)
    mapped_params = 
      [:idea_id, :idea_title, :idea_date, :idea_mac, 
       :citizen_id, 
       :accept_general, :accept_non_eu_server, :accept_publicity, :accept_science,
       :service, :success_auth_url
      ].map do |key| 
        raise "unknown param #{key}" unless parameters[:message].has_key? key
        [key, parameters[:message][key]]
      end +
      [:success_url, :failure_url].map do |key| 
        raise "unknown param #{key}" unless parameters[:options].has_key? key
        [key, parameters[:options][key]]
      end +
      [:last_fill_first_names, :last_fill_last_names, :last_fill_birth_date, :last_fill_occupancy_county, 
       :authentication_token, :authenticated_at].map do |key| 
        raise "unknown param #{key}" unless parameters.has_key? key
        [key, parameters[key]]
      end
    param_string = mapped_params.map{|key, value| h={}; h[key] = value; h.to_param }.join("&")
  end

  def validate_begin_authenticating_parameters!
    [ [ params[:message], [
      ] ],
      [ params[:options], [
        # Review: strict URL validation is very difficult
        #[:success_url,                  /^[\w\/\:\?\=\&]+$/ ],
        #[:failure_url,                  /^[\w\/\:\?\=\&]+$/ ],
      ] ],
      [ params, [
        [:last_fill_first_names,        /^[[:alpha:]\s]*$/ ],
        [:last_fill_last_names,         /^[[:alpha:]\s]*$/ ],
        [:last_fill_birth_date,         /^(\d\d\d\d-\d\d-\d\d)?$/ ],
        [:last_fill_occupancy_county,   /^[[:alpha:]\s]*$/ ],
        [:authentication_token,         /^\h*$/ ],
        [:authenticated_at,             /^(\d\d\d\d-\d\d-\d\dT\d\d:\d\d:\d\d[+\-]\d\d:\d\d)?$/ ],
      ] ], 
    ].map { |parameters, param_spec| validate_params(parameters, param_spec) }.all? or raise "Invalid parameters"
  end

  # used to validate hashes of parameters
  def validate_params(parameters, param_spec)
    param_spec.map {|param_key, regexp| validate_param(parameters, param_key, regexp) }.all?
  end

  def validate_param(parameters, param_key, regexp)
    regexp.match(parameters[param_key]) or (Rails.logger.info "Failed parameter value for #{param_key}: '#{parameters[param_key]}'" and false)
  end

  def mac(string)
    Digest::SHA256.new.update(string).hexdigest.upcase
  end

  def same_service?(signature, service_name)
    service_name_to_param(signature.service) == service_name
  end

  def service_name_to_param(service_name)
    service_name.gsub(/\s+/, "")
  end

  def valid_returning?(signature, service_name)
    values = %w(VERS TIMESTMP IDNBR STAMP CUSTNAME KEYVERS ALG CUSTID CUSTTYPE).map {|key| params["B02K_" + key]}
    string = values[0,9].join("&") + "&" + service_secret(service_name) + "&"
    params["B02K_MAC"] == mac(string)
  end

  def signal_successful_authentication
    retries, max_retries = 0, 3
    begin
      response = HTTParty.get(@signature.success_auth_url, timeout: 7.0)
      if response.code == 200
        Rails.logger.info "Successful signal_successful_authentication for signature.id=#{@signature.id} signature.user=#{@signature.citizen_id} signature.stamp=#{@signature.stamp}"
      else
        Rails.logger.error "Failed after connection, could not signal_successful_authentication with url #{@signature.success_auth_url} for signature.id=#{@signature.id} signature.user=#{@signature.citizen_id} signature.stamp=#{@signature.stamp} and response.code=#{response.code}"
      end
    rescue StandardError => e  # Timeout::Error => e    # originally only Timeout errors but actually all errors should yield the same (like DNS down)
      if (retries += 1) >= max_retries
        Rails.logger.error "Failed at trying due to #{e}, could not signal_successful_authentication with url #{@signature.success_auth_url} for signature.id=#{@signature.id} signature.user=#{@signature.citizen_id} signature.stamp=#{@signature.stamp}"
        # give up
        return 
      else
        retry
      end
    end
  end

  def check_previously_signed(current_citizen_id, idea_id)
    return false if ENV["ALLOW_SIGNING_MULTIPLE_TIMES"]

    completed_signature = Signature.where(state: "signed", citizen_id: current_citizen_id, idea_id: idea_id).first
    if completed_signature
      true
    else
      false
    end
  end

  def hetu_to_birth_date(hetu)
    date_part = hetu.gsub(/\-.+$/, "")
    year = date_part[4,2].to_i + hetu_separator_as_years(hetu)
    birth_date = Date.new(year, date_part[2,2].to_i, date_part[0,2].to_i)
  end

  # the latter part fixes -, + or A in HETU separator
  def hetu_separator_as_years(hetu)
    # convert 010203+1234 as years from 1800
    # convert 010203A1234 as years from 2000
    # otherwise it's year from 1900
    hetu[6,1] == "+" ? 1800 : hetu[6,1] == "A" ? 2000 : 1900
  end

  def invalid_mac(invalid_mac_exception)
    Rails.logger.info "Invalid MAC for Signature message"
    render :text => "403 Invalid MAC #{invalid_mac_exception}", :status => 403
  end

  def record_not_found
    Rails.logger.info "Signature not found with ID #{params[:id]} and citizen #{current_citizen_id}"
    render :text => "404 Signature Not Found", :status => 404
  end

  def signature_expired
    render :text => "403 Signature Expired", :status => 403
  end

  def current_citizen_id
    session[:current_citizen_id]
  end

  def parse_datetime(str)
    if str =~ /\d\d\d\d-\d\d-\d\d/
      begin 
        DateTime.parse(str)
      rescue
        nil
      end
    else 
      nil
    end
  end

  def authentication_age(authenticated_at)
    (DateTime.now - DateTime.parse(authenticated_at))
  end

  def minutes(mins)
    mins_of_day = 1.0/24/60
    mins * mins_of_day
  end

end
