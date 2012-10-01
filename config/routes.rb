Signing::Application.routes.draw do
#  match "/signatures"                             => "signatures#begin_authenticating", via: :post, as: :signature_begin_authenticating
#  match "/signatures"                             => "signatures#begin_authenticating", via: :post, as: :signature_begin_authenticating
  match "/signatures"                             => "signatures#begin_authenticating", via: :get, as: :signature_begin_authenticating
  match "/signatures/:id/finalize_signing"        => "signatures#finalize_signing",     via: :put
  match "/signatures/:id/returning/:servicename"  => "signatures#returning"             # originally via: :get but Sampo returns with :post
  match "/signatures/:id/cancelling/:servicename" => "signatures#cancelling"
  match "/signatures/:id/rejecting/:servicename"  => "signatures#rejecting"

  match "/heartbeat"                              => "heartbeats#index",                via: :get
end
