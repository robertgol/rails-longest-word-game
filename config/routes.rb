Rails.application.routes.draw do
  get "up" => "rails/health#show", :as => :rails_health_check

  root "games#new"

  post "score" => "games#create", :as => :create_score
  get "score" => "games#score"
end
