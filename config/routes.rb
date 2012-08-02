Signing::Application.routes.draw do
  match "/signatures" => "signatures#select_provider", via: :post, as: :signature_sign_idea
  match "/signatures/:id/finalize_signing" => "signatures#finalize_signing", via: :put
  match "/signatures/:id/returning/:servicename" => "signatures#returning", via: :get
  match "/signatures/:id/cancelling/:servicename" => "signatures#cancelling", via: :get
  match "/signatures/:id/rejecting/:servicename" => "signatures#rejecting", via: :get
end
