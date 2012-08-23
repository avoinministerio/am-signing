
#encoding: UTF-8

require 'signatures_controller_helpers'

class SignaturesController < ApplicationController

  include SignaturesControllerHelpers

  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  rescue_from SignatureExpired, :with => :signature_expired
  rescue_from InvalidMac, :with => :invalid_mac

  respond_to :html

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

  # Start signing an idea
  def begin_authenticating
    validate_requestor!

    # ERROR: Check that user has not signed already
    # TODO FIXME: check if user don't have any in-progress signatures
    # ie. cover case when user does not type in the url (when Sign button is not shown)

    @signature = Signature.create! params[:message]
    session[:current_citizen_id] = @signature.citizen_id
    session[:am_success_url] = params[:options][:success_url]
    session[:am_failure_url] = params[:options][:failure_url]
    
    birth_date, authenticated_at, authentication_token = params[:last_fill_birth_date], params[:authenticated_at], params[:authentication_token]
    if( birth_date and parse_datetime(birth_date) and 
        authenticated_at and parse_datetime(authenticated_at) and 
        authentication_token and authentication_token =~ /^[0-9A-F]+$/)
      mins = 1.0/24/60
      authentication_valid = 2 * mins
      auth_token = authentication_token(birth_date, authenticated_at)
      valid_authentication_token =  auth_token == authentication_token
      authentication_recent_enough = (DateTime.now - DateTime.parse(authenticated_at)) < authentication_valid
      if valid_authentication_token and authentication_recent_enough
        return shortcut_returning
      end
    end

    @service = find_service params[:options][:service]
    set_signature_specific_values @signature, @service
    set_mac @service

    render
  end

  def returning
    @signature = Signature.find_initial_for_citizen(params[:id], current_citizen_id)
    # TO-DO: Impelement checks for valid_returning?. Maybe it should be moved out of this class.

    birth_date = hetu_to_birth_date(params["B02K_CUSTID"])
    first_names, last_name = guess_names(params["B02K_CUSTNAME"], @signature.first_names, @signature.last_name)

    @signature.authenticate first_names, last_name, birth_date

    Rails.logger.info "All success, authentication ok, storing into session"
    session["authenticated_at"]         = DateTime.now
    session["authenticated_birth_date"] = birth_date
    session["authenticated_approvals"]  = @signature.id

    respond_with @signature
  end

  def finalize_signing
    @signature = Signature.find_authenticated_by_citizen params[:id], current_citizen_id

    # TODO: and duration since last authentication less that threshold. Validation?
    if @signature.sign params["signature"]["first_names"], params["signature"]["last_name"],
      params["signature"]["occupancy_county"], params["signature"]["vow"]
      # TO-DO: create Service Identifying MAC
      other_params = {
        first_names:          @signature.first_names,
        last_name:            @signature.last_name,
        occupancy_county:     @signature.occupancy_county,
        authenticated_at:     session["authenticated_at"],
        birth_date:           @signature.birth_date,
        authentication_token: authentication_token(@signature.birth_date, session["authenticated_at"]),
      }
      url = session[:am_success_url] + "?" + other_params.map {|name, value| h={}; h[name]=value; h.to_param}.join("&")
      puts(url + "&requestor_secret=#{ENV['requestor_secret']}")
      puts(mac(url + "&requestor_secret=#{ENV['requestor_secret']}"))
      service_provider_mac = mac(url + "&requestor_secret=#{ENV['requestor_secret']}")
      redirect_to(url + "&service_provider_identifying_mac=#{service_provider_mac}")
    else
      render "returning"
    end
  end

  def shortcut_returning
    @signature.authenticate params["last_fill_first_names"], params["last_fill_last_names"], params["last_fill_birth_date"]
    @signature.occupancy_county = params["last_fill_occupancy_county"]
    @signature.save

    Rails.logger.info "Shortcut success, authentication ok, storing into session"
    session["authenticated_at"]         = DateTime.now
    session["authenticated_birth_date"] = @signature.birth_date
    session["authenticated_approvals"]  = @signature.id

    p @signature
    p @signature.id
    render "shortcut_returning"
  end

  private

  def authentication_token(birth_date, authenticated_at)
    authentication_token_secret = ENV['authentication_token_secret'] || ""
    puts "Calculating authentication token"
    p birth_date, authenticated_at, authentication_token_secret
    mac(birth_date.to_s + authenticated_at.to_s + authentication_token_secret)
  end

  # This method should be replaced with TUPAS gem by jaakkos
  def find_service name
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

    service = services.find { |s| s[:name] == name }
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

    service_name = service[:name].gsub(/\s+/, "")
    service[:retlink] = "#{server}/signatures/#{signature.id}/returning/#{service_name}"
    service[:canlink] = "#{server}/signatures/#{signature.id}/cancelling/#{service_name}"
    service[:rejlink] = "#{server}/signatures/#{signature.id}/rejecting/#{service_name}"
  end

  def set_mac service
    secret = service_secret(service[:name])
    keys = [:action_id, :vers, :rcvid, :langcode, :stamp, :idtype, :retlink, :canlink, :rejlink, :keyvers, :alg]
    vals = keys.map{|k| service[k] }
    string = vals.join("&") + "&" + secret + "&"
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

  def requestor_params_as_string(parameters)
    mapped_params = 
      [:idea_id, :idea_title, :idea_date, :idea_mac, 
       :citizen_id, 
       :accept_general, :accept_non_eu_server, :accept_publicity, :accept_science,
      ].map do |key| 
        raise "unknown param #{key}" unless parameters[:message].has_key? key
        [key, parameters[:message][key]]
      end +
      [:service, :success_url, :failure_url].map do |key| 
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

  def validate_requestor!
    param_string = requestor_params_as_string(params) + "&requestor_secret=#{ENV['requestor_secret']}"
    unless params[:requestor_identifying_mac] == mac(param_string)
      raise InvalidMac.new(params.dup, param_string, mac(param_string), ENV['requestor_secret'])
    end
  end

  def validate_hmac!
    key = ENV["hmac_key"]
    calculated_hmac = Signing::HmacSha256.sign_array key, params[:message].merge(params[:options]).values
    raise InvalidMac.new unless calculated_hmac == params[:hmac]
  end

  def secret_to_mac_string(secret)
    str = ""
    secret.split(//).each_slice(2){|a| str += a.join("").hex.chr}
    p str
    str
  end

  def mac(string)
    Digest::SHA256.new.update(string).hexdigest.upcase
  end

  def valid_returning?(signature, service_name)
    values = %w(VERS TIMESTMP IDNBR STAMP CUSTNAME KEYVERS ALG CUSTID CUSTTYPE).map {|key| params["B02K_" + key]}
    string = values[0,9].join("&") + "&" + service_secret(service_name) + "&"
    params["B02K_MAC"] == mac(string)
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
end
