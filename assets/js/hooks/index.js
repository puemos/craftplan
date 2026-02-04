import OrderCalendar from "./order_calendar";
import KanbanDragDrop from "./kanban_drag_drop";
import CommandPalette from "./command_palette";

const Hooks = {
  TimezoneInput: {
    mounted() {
      this.el.value = Intl.DateTimeFormat().resolvedOptions().timeZone;
    },
  },
  OrderCalendar,
  KanbanDragDrop,
  CommandPalette,
};

export default Hooks;
