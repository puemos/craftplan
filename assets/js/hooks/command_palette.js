const CommandPalette = {
  mounted() {
    this.handleKeyDown = this.handleKeyDown.bind(this);
    document.addEventListener("keydown", this.handleKeyDown);
  },

  destroyed() {
    document.removeEventListener("keydown", this.handleKeyDown);
  },

  pushToComponent(event, payload = {}) {
    // Push event directly to the LiveComponent using the element's phx-target
    this.pushEventTo(`#${this.el.id}`, event, payload);
  },

  handleKeyDown(e) {
    const isMac = navigator.platform.toUpperCase().indexOf("MAC") >= 0;
    const modKey = isMac ? e.metaKey : e.ctrlKey;

    // Open palette with Cmd+K (Mac) or Ctrl+K (Windows/Linux)
    if (modKey && e.key === "k") {
      e.preventDefault();
      this.pushToComponent("open");
      return;
    }

    // Only handle navigation keys when palette is open
    const isOpen = this.el.dataset.open === "true";
    if (!isOpen) return;

    switch (e.key) {
      case "ArrowDown":
        e.preventDefault();
        this.pushToComponent("navigate", { direction: "down" });
        break;
      case "ArrowUp":
        e.preventDefault();
        this.pushToComponent("navigate", { direction: "up" });
        break;
      case "Enter":
        e.preventDefault();
        this.pushToComponent("select");
        break;
      case "Escape":
        e.preventDefault();
        this.pushToComponent("close");
        break;
    }
  },
};

export default CommandPalette;
