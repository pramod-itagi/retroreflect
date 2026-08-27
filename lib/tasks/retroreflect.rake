namespace :retroreflect do
  desc "Create the initial System Admin account (NAME, EMAIL, PASSWORD)"
  task create_system_admin: :environment do
    name = env_or_prompt("NAME", "Name")
    email = env_or_prompt("EMAIL", "Email")
    password = env_or_prompt("PASSWORD", "Password", secret: true)
    confirmation = ENV["PASSWORD_CONFIRMATION"].presence || password

    user = Users::CreateSystemAdmin.new(
      name: name,
      email: email,
      password: password,
      password_confirmation: confirmation
    ).call

    puts "Created System Admin #{user.email}."
  rescue Users::CreateSystemAdmin::Error => e
    abort e.message
  rescue ActiveRecord::RecordInvalid => e
    abort e.record.errors.full_messages.to_sentence
  end
end

def env_or_prompt(key, label, secret: false)
  value = ENV[key].to_s.strip
  return value if value.present?

  abort "Provide #{key} as an environment variable, or run this task in an interactive terminal." unless $stdin.tty?

  $stderr.print "#{label}: "
  value = if secret
            require "io/console"
            $stdin.noecho(&:gets).to_s.strip.tap { $stderr.puts }
          else
            $stdin.gets.to_s.strip
          end
  abort "#{label} can't be blank." if value.blank?

  value
end
