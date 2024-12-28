defmodule MicrocraftWeb.Router do
  use MicrocraftWeb, :router
  use AshAuthentication.Phoenix.Router
  import PhoenixStorybook.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MicrocraftWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", MicrocraftWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated_routes,
      on_mount: {MicrocraftWeb.LiveUserAuth, :live_user_required} do
      live "/backoffice/products", ProductLive.Index, :index
      live "/backoffice/products/new", ProductLive.Index, :new
      live "/backoffice/products/:id", ProductLive.Show, :show
      live "/backoffice/products/:id/edit", ProductLive.Show, :edit

      live "/backoffice/inventory", InventoryLive.Index, :index
      live "/backoffice/inventory/new", InventoryLive.Index, :new
      live "/backoffice/inventory/:id", InventoryLive.Show, :show
      live "/backoffice/inventory/:id/edit", InventoryLive.Show, :edit
      live "/backoffice/inventory/:id/adjust", InventoryLive.Show, :adjust

      live "/backoffice/orders", OrderLive.Index, :index
      live "/backoffice/orders/new", OrderLive.Index, :new
      live "/backoffice/orders/:id/edit", OrderLive.Show, :edit
      live "/backoffice/orders/:id", OrderLive.Show, :show

      live "/backoffice/customers", CustomerLive.Index, :index
      live "/backoffice/customers/new", CustomerLive.Index, :new
      live "/backoffice/customers/:id/edit", CustomerLive.Index, :edit
      live "/backoffice/customers/:id", CustomerLive.Show, :show

      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {MicrocraftWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {MicrocraftWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {MicrocraftWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", MicrocraftWeb do
    pipe_through :browser

    get "/", PageController, :home
    auth_routes AuthController, Microcraft.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{MicrocraftWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    MicrocraftWeb.AuthOverrides,
                    AshAuthentication.Phoenix.Overrides.Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  MicrocraftWeb.AuthOverrides,
                  AshAuthentication.Phoenix.Overrides.Default
                ]
  end

  # Other scopes may use custom stacks.
  # scope "/api", MicrocraftWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:microcraft, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: MicrocraftWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      storybook_assets()
    end

    scope "/", Elixir.MicrocraftWeb do
      pipe_through(:browser)
      live_storybook("/storybook", backend_module: Elixir.MicrocraftWeb.Storybook)
    end
  end
end
