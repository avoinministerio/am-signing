# encoding: UTF-8

module SignaturesControllerHelpers
  def hetu_like(hetu)
    hetu =~ /^\d{6}[\-+A]\d{3}[A-Z\d]$/
  end

  def shortcut_session_valid_time
    valid_mins = 3.0
    (valid_mins / 60.0) * (1.0/24)
  end

  def check_shortcut_session_validity
    current_citizen and session["authenticated_at"] and shortcut_session_remaining_mins > 0.0
  end

  def shortcut_session_remaining_mins
    if current_citizen and session["authenticated_at"]
     remaining = (shortcut_session_valid_time - (DateTime.now - session["authenticated_at"])) * 24.0*60.0
    else
      0.0
    end
  end

end
