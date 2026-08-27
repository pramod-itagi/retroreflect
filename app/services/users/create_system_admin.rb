module Users
  class CreateSystemAdmin
    class Error < StandardError; end

    ALREADY_EXISTS_MESSAGE = "A System Admin already exists. Add additional System Admins from System Administration.".freeze

    def initialize(name:, email:, password:, password_confirmation:)
      @name = name
      @email = email
      @password = password
      @password_confirmation = password_confirmation
    end

    def call
      raise Error, ALREADY_EXISTS_MESSAGE if User.where(system_admin: true).exists?

      user = User.new(
        name: @name,
        email: @email,
        password: @password,
        password_confirmation: @password_confirmation,
        system_admin: true,
        confirmed_at: Time.current
      )

      raise Error, user.errors.full_messages.to_sentence unless user.save

      user
    end
  end
end
