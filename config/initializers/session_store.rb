Rails.application.config.session_store :cookie_store,
                                       key: "_retroreflect_session",
                                       httponly: true,
                                       same_site: :lax,
                                       expire_after: 14.days,
                                       secure: Rails.env.production?
