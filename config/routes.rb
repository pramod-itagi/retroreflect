Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "home#show"

  resource :session, only: %i[new create destroy]
  resources :registrations, only: %i[new create]
  resources :email_confirmations, only: :show, param: :token
  resources :password_resets, only: %i[new create], param: :token
  get "password_resets/:token/edit", to: "password_resets#edit", as: :edit_password_reset
  patch "password_resets/:token", to: "password_resets#update", as: :password_reset

  get "invitations/:token", to: "invitations#show", as: :invitation

  resources :retrospectives, only: :index

  namespace :facilitator do
    resources :teams, only: %i[index show new create] do
      resources :memberships, only: %i[create destroy]
      resources :retrospectives, only: %i[new create]
      resources :action_items, only: :create
      resource :archive, only: %i[new create], controller: "team_archives"
    end

    resources :retrospectives, only: :show do
      member do
        post :start_collecting
        post :reveal
        post :close
        post :cancel
      end
      resources :participations, only: %i[create destroy]
      resource :meeting, only: :show
      resources :action_items, only: :create
    end

    resources :action_items, only: :update
  end

  namespace :participant do
    resources :retrospectives, only: :show do
      resources :drafts, only: %i[create update destroy] do
        collection do
          post :save
        end
      end
      resource :submission, only: %i[new create]
    end
    resources :action_items, only: %i[index update]
  end
end
