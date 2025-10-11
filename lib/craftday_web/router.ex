defmodule CraftdayWeb.Router do
  use CraftdayWeb, :router
  use AshAuthentication.Phoenix.Router

  alias AshAuthentication.Phoenix.Overrides.Default
  alias Craftday.Cart

  #
  # Plugs
  #
  # Content Security Policy compatible with LiveView and topbar
  @csp Enum.join([
          "default-src 'self'",
          "base-uri 'self'",
          "frame-ancestors 'self'",
          "img-src 'self' data: blob:",
          "style-src 'self' 'unsafe-inline'",
          "font-src 'self' data:",
          "script-src 'self' 'unsafe-inline' 'unsafe-eval'",
          "connect-src 'self' ws: wss:"
        ], "; ")

  def put_cart(conn, _opts) do
    cart =
      case get_session(conn, :cart_id) do
        nil ->
          {:ok, cart} = Cart.create_cart(%{items: []})
          cart

        cart_id ->
          Cart.get_cart_by_id!(cart_id)
      end

    put_session(conn, :cart_id, cart.id)
  end

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
    plug :put_root_layout, html: {CraftdayWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :put_csp
    plug :load_from_session
    plug :put_session_timezone
    plug :put_cart
  end

  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer
  end

  #
  # Public Routes
  #

  scope "/", CraftdayWeb do
    pipe_through :browser

    get "/", PageController, :home
    post "/cart/clear", CartController, :clear

    # Authentication Routes
    auth_routes AuthController, Craftday.Accounts.User, path: "/auth"
    sign_out_route AuthController

    sign_in_route register_path: "/register",
                  reset_path: "/reset",
                  auth_routes_prefix: "/auth",
                  on_mount: [
                    CraftdayWeb.LiveCurrentPath,
                    CraftdayWeb.LiveCart,
                    {CraftdayWeb.LiveUserAuth, :live_no_user}
                  ],
                  overrides: [
                    CraftdayWeb.AuthOverrides,
                    Default
                  ]

    reset_route auth_routes_prefix: "/auth",
                overrides: [
                  CraftdayWeb.AuthOverrides,
                  Default
                ]

    # Public LiveView Routes
    live_session :public,
      on_mount: [
        CraftdayWeb.LiveCurrentPath,
        CraftdayWeb.LiveSettings,
        CraftdayWeb.LiveCart
      ] do
      live "/catalog", Public.CatalogLive.Index, :index
      live "/catalog/:sku", Public.CatalogLive.Show, :show
      live "/cart", Public.CartLive.Index, :index
      live "/checkout", Public.CheckoutLive.Index, :index
    end
  end

  #
  # Authenticated Routes
  #

  scope "/", CraftdayWeb do
    pipe_through :browser

    # Admin Routes
    ash_authentication_live_session :admin_routes,
      on_mount: [
        CraftdayWeb.LiveCurrentPath,
        CraftdayWeb.LiveSettings,
        CraftdayWeb.LiveCart,
        {CraftdayWeb.LiveUserAuth, :live_admin_required}
      ] do
      # Settings Routes
      live "/manage/settings", SettingsLive.Index, :index
      live "/manage/settings/general", SettingsLive.Index, :general
      live "/manage/settings/allergens", SettingsLive.Index, :allergens
      live "/manage/settings/nutritional_facts", SettingsLive.Index, :nutritional_facts
    end

    # Staff Routes
    ash_authentication_live_session :manage_routes,
      on_mount: [
        CraftdayWeb.LiveCurrentPath,
        CraftdayWeb.LiveSettings,
        CraftdayWeb.LiveCart,
        {CraftdayWeb.LiveUserAuth, :live_staff_required}
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

      # Customers
      live "/manage/customers", CustomerLive.Index, :index
      live "/manage/customers/new", CustomerLive.Index, :new
      live "/manage/customers/:reference", CustomerLive.Show, :show
      live "/manage/customers/:reference/details", CustomerLive.Show, :details
      live "/manage/customers/:reference/orders", CustomerLive.Show, :orders
      live "/manage/customers/:reference/statistics", CustomerLive.Show, :statistics
      live "/manage/customers/:reference/edit", CustomerLive.Index, :edit

      # Planning
      live "/manage/plan", PlanLive.Index, :index
      live "/manage/plan/schedule", PlanLive.Index, :schedule
      live "/manage/plan/materials", PlanLive.Index, :materials

      # in each liveview, add one of the following at the top of the module:
      #
      # If an authenticated user must be present:
      # on_mount {CraftdayWeb.LiveUserAuth, :live_user_required}
      #
      # If an authenticated user *may* be present:
      # on_mount {CraftdayWeb.LiveUserAuth, :live_user_optional}
      #
      # If an authenticated user must *not* be present:
      # on_mount {CraftdayWeb.LiveUserAuth, :live_no_user}
    end
  end

  #
  # API Routes
  #

  # Other scopes may use custom stacks.
  # scope "/api", CraftdayWeb do
  #   pipe_through :api
  # end

  #
  # Development Routes
  #

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:craftday, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: CraftdayWeb.Telemetry
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
