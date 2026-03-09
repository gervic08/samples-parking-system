namespace :api, defaults: {format: :json}, path: nil do
  namespace :v1 do
    resource :auth, only: [:create, :destroy] do
      collection do
        post :refresh
      end
    end

    resources :payments, only: [:create]
  end
end
