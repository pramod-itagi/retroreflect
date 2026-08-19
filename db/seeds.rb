return unless Rails.env.development?

def seed_confirmed_user(name:, email:)
  user = User.find_or_initialize_by(email: email)
  user.name = name
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at ||= Time.current
  user.save!
  user
end

seed_confirmed_user(name: "Jordan Facilitator", email: "jordan@example.com")
seed_confirmed_user(name: "Alice Member", email: "alice@example.com")
seed_confirmed_user(name: "Bob Member", email: "bob@example.com")
