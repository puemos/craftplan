defmodule CraftplanWeb.Router do
  use CraftplanWeb, :router
  use AshAuthentication.Phoenix.Router

  alias AshAuthentication.Phoenix.Overrides.Default

  #
  # Plugs
  #
  # Content Security Policy compatible with LiveView and topbar
  @csp Enum.join(
         [
           "default-src 'self'",
           "base-uri 'self'",
           "frame-ancestors 'self'",
           "img-src 'self' data: blob:",
           "style-src 'self' 'unsafe-inline'",
           "font-src 'self' data:",
           "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
           "connect-src 'self' ws: wss:"
         ],
         "; "
       )

  def put_session_timezone(conn, _opts) do
    timezone = conn.cookies["timezone"]
    put_session(conn, "timezone", timezone)
  end

  #
  # Pipelines
  #

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {CraftplanWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_csp
    plug :load_from_session
    plug :put_session_timezone
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  #
  # Public Routes
  #

  scope "/", CraftplanWeb do
    pipe_through :browser

    get "/", PageController, :home
    # Authentication Routes
    auth_routes AuthController, Craftplan.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [
                    CraftplanWeb.LiveCurrentPath,
                    {CraftplanWeb.LiveUserAuth, :live_no_user}
                  ],
                  overrides: [
                    CraftplanWeb.AuthOverrides,
                    Default
                  ]

    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  CraftplanWeb.AuthOverrides,
                  Default
                ]
  end

  #
  # Authenticated Routes
  #

  scope "/", CraftplanWeb do
    pipe_through :browser

    # Admin Routes
    ash_authentication_live_session :admin_routes,
      on_mount: [
        CraftplanWeb.LiveCurrentPath,
        CraftplanWeb.LiveNav,
        CraftplanWeb.LiveSettings,
        {CraftplanWeb.LiveUserAuth, :live_admin_required}
      ] do
      # Settings Routes
      live "/manage/settings", SettingsLive.Index, :index
      live "/manage/settings/general", SettingsLive.Index, :general
      live "/manage/settings/allergens", SettingsLive.Index, :allergens
      live "/manage/settings/nutritional_facts", SettingsLive.Index, :nutritional_facts
      live "/manage/settings/csv", SettingsLive.Index, :csv
    end

    # Staff Routes
    ash_authentication_live_session :manage_routes,
      on_mount: [
        CraftplanWeb.LiveCurrentPath,
        CraftplanWeb.LiveNav,
        CraftplanWeb.LiveSettings,
        {CraftplanWeb.LiveUserAuth, :live_staff_required}
      ] do
      # Products
      live "/manage/products", ProductLive.Index, :index
      live "/manage/products/new", ProductLive.Index, :new
      live "/manage/products/:sku", ProductLive.Show, :show
      live "/manage/products/:sku/details", ProductLive.Show, :details
      live "/manage/products/:sku/recipe", ProductLive.Show, :recipe
      live "/manage/products/:sku/nutrition", ProductLive.Show, :nutrition
      live "/manage/products/:sku/photos", ProductLive.Show, :photos
      live "/manage/products/:sku/edit", ProductLive.Show, :edit
      live "/manage/products/:sku/label", ProductLive.Label, :label

      # Inventory
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

      # Orders
      live "/manage/orders", OrderLive.Index, :index
      live "/manage/orders/new", OrderLive.Index, :new
      live "/manage/orders/:reference", OrderLive.Show, :show
      live "/manage/orders/:reference/details", OrderLive.Show, :details
      live "/manage/orders/:reference/items", OrderLive.Show, :items
      live "/manage/orders/:reference/edit", OrderLive.Show, :edit
      live "/manage/orders/:reference/invoice", OrderLive.Invoice, :show

      # Purchasing
      live "/manage/purchasing", PurchasingLive.Index, :index
      live "/manage/purchasing/new", PurchasingLive.Index, :new
      # Specific suppliers routes must come before the catch-all :po_ref
      live "/manage/purchasing/suppliers", PurchasingLive.Suppliers, :index
      live "/manage/purchasing/suppliers/new", PurchasingLive.Suppliers, :new
      live "/manage/purchasing/suppliers/:id/edit", PurchasingLive.Suppliers, :edit
      # Purchase order routes (by reference)
      live "/manage/purchasing/:po_ref/items", PurchasingLive.Show, :items
      live "/manage/purchasing/:po_ref", PurchasingLive.Show, :show
      live "/manage/purchasing/:po_ref/add_item", PurchasingLive.Show, :add_item

      # Customers
      live "/manage/customers", CustomerLive.Index, :index
      live "/manage/customers/new", CustomerLive.Index, :new
      live "/manage/customers/:reference", CustomerLive.Show, :show
      live "/manage/customers/:reference/details", CustomerLive.Show, :details
      live "/manage/customers/:reference/orders", CustomerLive.Show, :orders
      live "/manage/customers/:reference/statistics", CustomerLive.Show, :statistics
      live "/manage/customers/:reference/edit", CustomerLive.Index, :edit

      # Production
      live "/manage/production", PlanLive.Index, :index
      live "/manage/production/schedule", PlanLive.Index, :schedule
      live "/manage/production/make_sheet", PlanLive.Index, :make_sheet
      live "/manage/production/materials", PlanLive.Index, :materials

      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {CraftplanWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {CraftplanWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {CraftplanWeb.LiveUserAuth, :live_no_user}
    end
  end

  #
  # API Routes
  #

  # Other scopes may use custom stacks.
  # scope "/api", CraftplanWeb do
  #   pipe_through :api
  # end

  #
  # Development Routes
  #

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:craftplan, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CraftplanWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end

  #
  # Content Security Policy
  #
  # Phoenix 1.8 secures defaults in `put_secure_browser_headers`. We provide an
  # explicit CSP compatible with LiveView, topbar, and dev websocket connections.
  # Tighten as needed for your deployment.
  defp put_csp(conn, _opts), do: Plug.Conn.put_resp_header(conn, "content-security-policy", @csp)
end
