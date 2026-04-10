import KanbanDragDrop from "./kanban_drag_drop";
import CommandPalette from "./command_palette";

const Hooks = {
  TimezoneInput: {
    mounted() {
      this.el.value = Intl.DateTimeFormat().resolvedOptions().timeZone;
    },
  },
  KanbanDragDrop,
  CommandPalette,
};

export default Hooks;
