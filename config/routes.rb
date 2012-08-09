Signing::Application.routes.draw do
  match "/signatures" => "signatures#begin_authenticating", via: :post, as: :signature_begin_authenticating
  match "/signatures/:id/finalize_signing" => "signatures#finalize_signing", via: :put
  match "/signatures/:id/returning/:servicename" => "signatures#returning", via: :get
  match "/signatures/:id/cancelling/:servicename" => "signatures#cancelling", via: :get
  match "/signatures/:id/rejecting/:servicename" => "signatures#rejecting", via: :get
end
