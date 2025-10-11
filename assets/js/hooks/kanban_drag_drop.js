const KanbanDragDrop = {
  mounted() {
    this.setupDragAndDrop();
  },

  updated() {
    this.setupDragAndDrop();
  },

  setupDragAndDrop() {
    const cards = this.el.querySelectorAll(".kanban-card");
    const columns = this.el.querySelectorAll(".kanban-column");

    // Setup drag events for cards
    cards.forEach((card) => {
      card.addEventListener("dragstart", (e) => {
        e.dataTransfer.effectAllowed = "move";
        e.dataTransfer.setData("text/html", card.innerHTML);

        // Store the card data
        const productId = card.dataset.productId;
        const date = card.dataset.date;
        const currentStatus = card.dataset.status;

        e.dataTransfer.setData(
          "application/json",
          JSON.stringify({
            productId,
            date,
            currentStatus,
          }),
        );

        card.classList.add("dragging");
      });

      card.addEventListener("dragend", (e) => {
        card.classList.remove("dragging");
      });

      // Prevent click when dragging
      card.addEventListener("click", (e) => {
        if (card.classList.contains("dragging")) {
          e.stopPropagation();
          e.preventDefault();
        }
      });
    });

    // Setup drop zones for columns
    columns.forEach((column) => {
      column.addEventListener("dragover", (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = "move";
        column.classList.add("drag-over");
      });

      column.addEventListener("dragleave", (e) => {
        if (e.target === column) {
          column.classList.remove("drag-over");
        }
      });

      column.addEventListener("drop", (e) => {
        e.preventDefault();
        column.classList.remove("drag-over");

        try {
          const data = JSON.parse(e.dataTransfer.getData("application/json"));
          const newStatus = column.dataset.status;

          // Only update if status changed
          if (data.currentStatus !== newStatus) {
            this.pushEvent("update_kanban_status", {
              product_id: data.productId,
              date: data.date,
              status: newStatus,
            });
          }
        } catch (err) {
          console.error("Error processing drop:", err);
        }
      });
    });
  },
};

export default KanbanDragDrop;
