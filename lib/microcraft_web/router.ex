defmodule MicrocraftWeb.Router do
  use MicrocraftWeb, :router
  use AshAuthentication.Phoenix.Router

  import PhoenixStorybook.Router

  alias AshAuthentication.Phoenix.Overrides.Default

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {MicrocraftWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
    plug :put_session_timezone
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  def put_session_timezone(conn, _opts) do
    timezone = conn.cookies["timezone"]
    put_session(conn, "timezone", timezone)
  end

  scope "/", MicrocraftWeb do
    pipe_through :browser

    ash_authentication_live_session :admin_routes,
      on_mount: [
        MicrocraftWeb.LiveCurrentPath,
        MicrocraftWeb.LiveSettings,
        {MicrocraftWeb.LiveUserAuth, :live_admin_required}
      ] do
      live "/manage/settings", SettingsLive.Index, :index
      live "/manage/settings/general", SettingsLive.Index, :general
      live "/manage/settings/allergens", SettingsLive.Index, :allergens
      live "/manage/settings/nutritional_facts", SettingsLive.Index, :nutritional_facts
    end

    ash_authentication_live_session :manage_routes,
      on_mount: [
        MicrocraftWeb.LiveCurrentPath,
        MicrocraftWeb.LiveSettings,
        {MicrocraftWeb.LiveUserAuth, :live_staff_required}
      ] do
      live "/manage/products", ProductLive.Index, :index
      live "/manage/products/new", ProductLive.Index, :new
      live "/manage/products/:sku", ProductLive.Show, :show
      live "/manage/products/:sku/details", ProductLive.Show, :details
      live "/manage/products/:sku/recipe", ProductLive.Show, :recipe
      live "/manage/products/:sku/nutrition", ProductLive.Show, :nutrition
      live "/manage/products/:sku/edit", ProductLive.Show, :edit

      live "/manage/inventory", InventoryLive.Index, :index
      live "/manage/inventory/forecast", InventoryLive.Index, :forecast
      live "/manage/inventory/new", InventoryLive.Index, :new
      live "/manage/inventory/:sku", InventoryLive.Show, :show
      live "/manage/inventory/:sku/details", InventoryLive.Show, :details
      live "/manage/inventory/:sku/allergens", InventoryLive.Show, :allergens
      live "/manage/inventory/:sku/nutritional_facts", InventoryLive.Show, :nutritional_facts
      live "/manage/inventory/:sku/stock", InventoryLive.Show, :stock
      live "/manage/inventory/:sku/edit", InventoryLive.Show, :edit
      live "/manage/inventory/:sku/adjust", InventoryLive.Show, :adjust

      live "/manage/orders", OrderLive.Index, :index
      live "/manage/orders/new", OrderLive.Index, :new
      live "/manage/orders/:reference", OrderLive.Show, :show
      live "/manage/orders/:reference/details", OrderLive.Show, :details
      live "/manage/orders/:reference/items", OrderLive.Show, :items
      live "/manage/orders/:reference/edit", OrderLive.Show, :edit

      live "/manage/customers", CustomerLive.Index, :index
      live "/manage/customers/new", CustomerLive.Index, :new
      live "/manage/customers/:reference", CustomerLive.Show, :show
      live "/manage/customers/:reference/details", CustomerLive.Show, :details
      live "/manage/customers/:reference/orders", CustomerLive.Show, :orders
      live "/manage/customers/:reference/statistics", CustomerLive.Show, :statistics
      live "/manage/customers/:reference/edit", CustomerLive.Index, :edit

      live "/manage/plan", PlanLive.Index, :index
      live "/manage/plan/schedule", PlanLive.Index, :schedule
      live "/manage/plan/materials", PlanLive.Index, :materials

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
                    Default
                  ]

    # Remove this if you do not want to use the reset password feature
    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  MicrocraftWeb.AuthOverrides,
                  Default
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
