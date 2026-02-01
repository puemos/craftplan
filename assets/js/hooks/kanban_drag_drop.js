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

    cards.forEach((card) => {
      card.setAttribute("draggable", "true");
      card.addEventListener("dragstart", (e) => {
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
      });
      card.addEventListener("dragend", () => card.classList.remove("dragging"));
    });

    columns.forEach((column) => {
      column.addEventListener("dragover", (e) => {
        e.preventDefault();
        e.dataTransfer.dropEffect = "move";
        column.classList.add("drag-over");
      });
      column.addEventListener("dragleave", (e) => {
        if (e.target === column) column.classList.remove("drag-over");
      });
      column.addEventListener("drop", (e) => {
        e.preventDefault();
        column.classList.remove("drag-over");
        try {
          const data = JSON.parse(
            e.dataTransfer.getData("application/json"),
          );
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
      });
    });
  },
};

export default KanbanDragDrop;
