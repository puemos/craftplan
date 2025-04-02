import OrderCalendar from './order_calendar';

const Hooks = {
  TimezoneInput: {
    mounted() {
      this.el.value = Intl.DateTimeFormat().resolvedOptions().timeZone;
    }
  },
  OrderCalendar
};

export default Hooks;