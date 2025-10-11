import OrderCalendar from "./order_calendar";
import KanbanDragDrop from "./kanban_drag_drop";

const Hooks = {
  TimezoneInput: {
    mounted() {
      this.el.value = Intl.DateTimeFormat().resolvedOptions().timeZone;
    },
  },
  OrderCalendar,
  KanbanDragDrop,
};

export default Hooks;
