import Calendar from "@event-calendar/core";
import TimeGrid from "@event-calendar/time-grid";
import DayGrid from "@event-calendar/day-grid";
import ListView from "@event-calendar/list";

// Import CSS
import "@event-calendar/core/index.css";

const OrderCalendar = {
  mounted() {
    // Setup calendar when the element is mounted
    let calendarEl = this.el;
    let orderEvents = JSON.parse(calendarEl.dataset.events || "[]");
    let initialView = calendarEl.dataset.view || "listMonth";

    this.calendar = new Calendar({
      target: calendarEl,
      props: {
        plugins: [TimeGrid, ListView, DayGrid],
        options: {
          view: initialView,
          events: orderEvents,
          eventClick: (info) => {
            // When an event is clicked, trigger a LiveView event to show a modal
            console.log(info.event);

            // Push event to the server with the event data
            this.pushEvent("show_event_modal", {
              eventId: info.event.id,
              title: info.event.title,
              start: info.event.start,
              end: info.event.end,
              url: info.event.url,
              allDay: info.event.allDay,
              // Include any other event properties you need in the modal
              extendedProps: info.event.extendedProps,
            });

            return false; // Prevents the default browser behavior
          },
          datesSet: (info) => {
            // When date range changes, send event to server to update filters
            const startDate = info.start.toISOString().split("T")[0]; // Get just the date part
            const endDate = info.end.toISOString().split("T")[0];
            const viewType = info.view.type;

            // Push the event to the server
            this.pushEvent("update_date_filters", {
              start_date: startDate,
              end_date: endDate,
              view_type: viewType,
            });
          },
        },
      },
    });
  },

  updated() {
    // Update calendar data when new data is pushed
    if (this.calendar) {
      let orderEvents = JSON.parse(this.el.dataset.events || "[]");
      this.calendar.$set({
        options: { events: orderEvents, view: this.el.dataset.view },
      });
    }
  },

  destroyed() {
    // Clean up when element is removed
    if (this.calendar) {
      this.calendar.$destroy();
    }
  },
};

export default OrderCalendar;
