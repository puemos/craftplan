defmodule CraftScaleWeb.Router do
  use CraftScaleWeb, :router
  use AshAuthentication.Phoenix.Router

  import PhoenixStorybook.Router

  alias AshAuthentication.Phoenix.Overrides.Default

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CraftScaleWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  scope "/", CraftScaleWeb do
    pipe_through :browser

    ash_authentication_live_session :admin_routes,
      on_mount: [CraftScaleWeb.LiveSettings, {CraftScaleWeb.LiveUserAuth, :live_admin_required}] do
      live "/manage/settings", SettingsLive.Index, :index
    end

    ash_authentication_live_session :manage_routes,
      on_mount: [CraftScaleWeb.LiveSettings, {CraftScaleWeb.LiveUserAuth, :live_staff_required}] do
      live "/manage/products", ProductLive.Index, :index
      live "/manage/products/new", ProductLive.Index, :new
      live "/manage/products/:id", ProductLive.Show, :show
      live "/manage/products/:id/edit", ProductLive.Show, :edit

      live "/manage/inventory", InventoryLive.Index, :index
      live "/manage/inventory/new", InventoryLive.Index, :new
      live "/manage/inventory/:id", InventoryLive.Show, :show
      live "/manage/inventory/:id/edit", InventoryLive.Show, :edit
      live "/manage/inventory/:id/adjust", InventoryLive.Show, :adjust

      live "/manage/orders", OrderLive.Index, :index
      live "/manage/orders/new", OrderLive.Index, :new
      live "/manage/orders/:id/edit", OrderLive.Show, :edit
      live "/manage/orders/:id", OrderLive.Show, :show

      live "/manage/customers", CustomerLive.Index, :index
      live "/manage/customers/new", CustomerLive.Index, :new
      live "/manage/customers/:id/edit", CustomerLive.Index, :edit
      live "/manage/customers/:id", CustomerLive.Show, :show

      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {CraftScaleWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {CraftScaleWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {CraftScaleWeb.LiveUserAuth, :live_no_user}
    end
  end

  scope "/", CraftScaleWeb do
    pipe_through :browser

    get "/", PageController, :home
    auth_routes AuthController, CraftScale.Accounts.User, path: "/auth"
    sign_out_route AuthController

    # Remove these if you'd like to use your own authentication views
    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [{CraftScaleWeb.LiveUserAuth, :live_no_user}],
                  overrides: [
                    CraftScaleWeb.AuthOverrides,
                    Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  CraftScaleWeb.AuthOverrides,
                  Default
                ]
  end

  # Other scopes may use custom stacks.
  # scope "/api", CraftScaleWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:craftscale, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CraftScaleWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    scope "/" do
      storybook_assets()
    end

    scope "/", Elixir.CraftScaleWeb do
      pipe_through(:browser)
      live_storybook("/storybook", backend_module: Elixir.CraftScaleWeb.Storybook)
    end
  end
end
