module ModelHelpers
  def create_user(name:, email: nil, password: "password123", confirmed: true, system_admin: false)
    user = User.create!(
      name: name,
      email: email || "#{name.downcase.gsub(/\s+/, '.')}@example.com",
      password: password,
      password_confirmation: password
    )
    user.update!(confirmed_at: Time.current) if confirmed
    user.update!(system_admin: true) if system_admin
    user
  end

  def create_team_with_roles(facilitator:, members: [], name: "Platform")
    team = Team.create!(name: name, created_by: facilitator)
    team.memberships.create!(user: facilitator, role: :facilitator)
    members.each { |member| team.memberships.create!(user: member, role: :member) }
    team
  end
end

RSpec.configure do |config|
  config.include ModelHelpers
end
