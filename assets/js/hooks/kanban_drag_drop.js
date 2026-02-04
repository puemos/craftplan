const KanbanDragDrop = {
  mounted() {
    this.setupDragAndDrop();
  },
  updated() {
    this.cleanupEventListeners();
    this.setupDragAndDrop();
  },
  destroyed() {
    this.cleanupEventListeners();
  },

  cleanupEventListeners() {
    if (this.cardListeners) {
      this.cardListeners.forEach(({ card, dragstart, dragend }) => {
        card.removeEventListener("dragstart", dragstart);
        card.removeEventListener("dragend", dragend);
      });
    }
    if (this.columnListeners) {
      this.columnListeners.forEach(({ column, dragover, dragleave, drop }) => {
        column.removeEventListener("dragover", dragover);
        column.removeEventListener("dragleave", dragleave);
        column.removeEventListener("drop", drop);
      });
    }
    this.cardListeners = [];
    this.columnListeners = [];
  },

  setupDragAndDrop() {
    const cards = this.el.querySelectorAll(".kanban-card");
    const columns = this.el.querySelectorAll(".kanban-column");

    this.cardListeners = [];
    this.columnListeners = [];

    cards.forEach((card) => {
      card.setAttribute("draggable", "true");

      const dragstart = (e) => {
        e.dataTransfer.effectAllowed = "move";

        const payload = card.dataset.batchCode
          ? {
              type: "batch",
              batchCode: card.dataset.batchCode,
              currentStatus: card.dataset.status,
            }
          : {
              type: "unbatched",
              productId: card.dataset.productId,
              currentStatus: "unbatched",
            };

        e.dataTransfer.setData("application/json", JSON.stringify(payload));
        card.classList.add("dragging");
      };

      const dragend = () => card.classList.remove("dragging");

      card.addEventListener("dragstart", dragstart);
      card.addEventListener("dragend", dragend);
      this.cardListeners.push({ card, dragstart, dragend });
    });

    columns.forEach((column) => {
      const dragover = (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = "move";
        column.classList.add("drag-over");
      };

      const dragleave = (e) => {
        if (e.target === column) column.classList.remove("drag-over");
      };

      const drop = (e) => {
        e.preventDefault();
        column.classList.remove("drag-over");
        try {
          const data = JSON.parse(e.dataTransfer.getData("application/json"));
          const newStatus = column.dataset.status;
          if (data.currentStatus !== newStatus) {
            if (data.type === "unbatched") {
              this.pushEvent("drop_unbatched", {
                product_id: data.productId,
                to: newStatus,
              });
            } else {
              this.pushEvent("drop_batch", {
                batch_code: data.batchCode,
                from: data.currentStatus,
                to: newStatus,
              });
            }
          }
        } catch (err) {
          console.error("Drop error:", err);
        }
      };

      column.addEventListener("dragover", dragover);
      column.addEventListener("dragleave", dragleave);
      column.addEventListener("drop", drop);
      this.columnListeners.push({ column, dragover, dragleave, drop });
    });
  },
};

export default KanbanDragDrop;
