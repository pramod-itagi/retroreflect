return unless Rails.env.development?

def seed_confirmed_user(name:, email:, system_admin: false)
  user = User.find_or_initialize_by(email: email)
  user.name = name
  user.password = "password123"
  user.password_confirmation = "password123"
  user.confirmed_at ||= Time.current
  user.system_admin = true if system_admin
  user.save!
  user
end

seed_confirmed_user(name: "Priya Admin", email: "admin@example.com", system_admin: true)
jordan = seed_confirmed_user(name: "Jordan Facilitator", email: "jordan@example.com")
alice = seed_confirmed_user(name: "Alice Member", email: "alice@example.com")
bob = seed_confirmed_user(name: "Bob Member", email: "bob@example.com")

platform = Team.find_or_initialize_by(name: "Platform")
platform.created_by ||= jordan
platform.save!
platform.memberships.find_or_create_by!(user: jordan) { |membership| membership.role = :facilitator }
platform.memberships.find_or_create_by!(user: alice) { |membership| membership.role = :member }
platform.memberships.find_or_create_by!(user: bob) { |membership| membership.role = :member }
