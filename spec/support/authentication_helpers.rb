module AuthenticationHelpers
  def sign_in(user, password: "password123")
    post session_path, params: { email: user.email, password: password }
  end
end
