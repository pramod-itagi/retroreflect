module Token
  module_function

  def generate
    raw = SecureRandom.urlsafe_base64(32)
    [raw, digest(raw)]
  end

  def digest(raw)
    Digest::SHA256.hexdigest(raw.to_s)
  end
end
