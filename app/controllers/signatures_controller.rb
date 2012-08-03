#encoding: UTF-8

require 'signatures_controller_helpers'

class SignaturesController < ApplicationController

  include SignaturesControllerHelpers

  rescue_from ActiveRecord::RecordNotFound, :with => :record_not_found
  rescue_from SignatureExpired, :with => :signature_expired

  respond_to :html

  # Start signing an idea by selecting a signature provider
  def select_provider
    # ERROR: Check that user has not signed already
    # TODO FIXME: check if user don't have any in-progress signatures
    # ie. cover case when user does not type in the url (when Sign button is not shown)
    @signature = Signature.create! params[:message]
    
    session[:current_citizen_id] = @signature.citizen_id
    session[:am_success_url] = params[:success_url]

    @services = [
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
        rcvid:      "KANNATUSTUPAS12",
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
      },
    ]

    @services.each do |service|
      set_defaults(service)
      set_mac(service)
    end

    render
  end

  def set_defaults(service)
    service[:action_id] = "701"
    service[:langcode]  = "FI"
    service[:keyvers]   = "0001"
    service[:alg]       = "03"
    service[:stamp]     = @signature.stamp

    service[:mac]       = nil
    # TO-DO: Needs to be HTTPS in production
    server = "http://#{request.host_with_port}"
    Rails.logger.info "Server is #{server}"

    service_name = service[:name].gsub(/\s+/, "")
    service[:retlink]   = "#{server}/signatures/#{@signature.id}/returning/#{service_name}"
    service[:canlink]   = "#{server}/signatures/#{@signature.id}/cancelling/#{service_name}"
    service[:rejlink]   = "#{server}/signatures/#{@signature.id}/rejecting/#{service_name}"
  end

  def set_mac(service)
    secret = service_secret(service[:name])
    keys = [:action_id, :vers, :rcvid, :langcode, :stamp, :idtype, :retlink, :canlink, :rejlink, :keyvers, :alg]
    vals = keys.map{|k| service[k] }
    string = vals.join("&") + "&" + secret + "&"
    service[:mac] = mac(string)
  end

  def service_secret(service)
    secret_key = "SECRET_" + service.gsub(/\s/, "")

    Rails.logger.info "Using key #{secret_key}"
    secret = ENV[secret_key] || ""

    # TODO: precalc the secret into environment variable, and remove this special handling
    if service == "Alandsbanken" or service == "Tapiola"
      secret = secret_to_mac_string(secret)
      Rails.logger.info "Converting secret to #{secret}"
    end

    unless secret
      Rails.logger.error "No SECRET found for #{secret_key}"
      secret = ""
    end

    secret
  end

  def secret_to_mac_string(secret)
    str = ""
    secret.split(//).each_slice(2){|a| str += a.join("").hex.chr}
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

  def cancelling
    @signature = Signature.find(params[:id])   # TODO: Add find for current_citizen
    if not @signature.citizen_id == current_citizen_id
      Rails.logger.info "Invalid user, not for the same user who initiated the signing"
      @error = "Invalid user"
    else
      service_name = params[:servicename]
      Rails.logger.info "Cancelling"
      @signature.update_attributes(state: "cancelled")
      @error = "Cancelling authentication"
    end
    respond_with @signature
  end

  def rejecting
    @signature = Signature.find(params[:id])   # TODO: Add find for current_citizen
    if not @signature.citizen == current_citizen
      Rails.logger.info "Invalid user, not for the same user who initiated the signing"
      @error = "Invalid user"
    else
      service_name = params[:servicename]
      Rails.logger.info "Rejecting"
      @signature.update_attributes(state: "rejected")
      @error = "Rejecting authentication"
    end
    respond_with @signature
  end

  def finalize_signing
    @signature = Signature.find_authenticated_by_citizen params[:id], current_citizen_id

    # TODO: and duration since last authentication less that threshold. Validation?
    if @signature.sign params["signature"]["first_names"], params["signature"]["last_name"],
      params["signature"]["occupancy_county"], params["signature"]["vow"]
      # TO-DO: create Service Identifying MAC
      redirect_to(session[:am_success_url])
    else
      @error = "Trying to alter other citizen or signature with other than authenticated state"
      render "returning"
    end
  end

  private

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
