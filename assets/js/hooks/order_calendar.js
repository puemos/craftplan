import Calendar from "@event-calendar/core";
import TimeGrid from "@event-calendar/time-grid";
import DayGrid from "@event-calendar/day-grid";
import ListView from "@event-calendar/list";

// Constants - Notion-like color scheme with subtle, muted colors
const STATUS_COLORS = {
  unconfirmed: "rgba(120, 119, 116, 0.4)", // gray
  confirmed: "rgba(51, 126, 169, 0.4)", // blue
  in_progress: "rgba(217, 115, 13, 0.4)", // orange
  ready: "rgba(15, 123, 108, 0.4)", // teal
  delivered: "rgba(11, 110, 153, 0.4)", // cyan
  completed: "rgba(68, 131, 97, 0.4)", // green
  cancelled: "rgba(212, 76, 71, 0.4)", // red
};

// Components
class EventTimeComponent {
  static render(timeText, status) {
    const timeRow = document.createElement("div");
    timeRow.className = "event-time-row";

    // Time element on the left
    const timeEl = document.createElement("div");
    timeEl.className = "event-time";
    timeEl.textContent = timeText;
    timeRow.appendChild(timeEl);

    // Status on the right in the same line as time
    const statusContainer = document.createElement("div");
    statusContainer.className = "status-container";

    // Status dot - Notion-like status indicator
    const statusDot = document.createElement("span");
    statusDot.className = "status-dot";
    statusDot.dataset.status = status;
    statusContainer.appendChild(statusDot);

    // Status text with proper capitalization
    const statusText = document.createElement("span");
    statusText.className = "status-text";
    statusText.textContent = StatusRowComponent.formatStatus(status);
    statusContainer.appendChild(statusText);

    timeRow.appendChild(statusContainer);

    return timeRow;
  }
}

class CustomerNameComponent {
  static render(customerName) {
    const nameContainer = document.createElement("div");
    nameContainer.className = "customer-name-container";

    // Customer name
    const nameEl = document.createElement("strong");
    nameEl.className = "customer-name";
    nameEl.textContent = customerName;
    nameContainer.appendChild(nameEl);

    return nameContainer;
  }
}

class StatusRowComponent {
  static formatStatus(status) {
    return status
      .replace(/_/g, " ")
      .split(" ")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(" ");
  }

  static render(status) {
    const secondaryRow = document.createElement("div");
    secondaryRow.className = "status-row";

    // Status text with dot indicator (Notion style)
    const statusContainer = document.createElement("div");
    statusContainer.className = "status-container";

    // Status dot - Notion-like status indicator
    const statusDot = document.createElement("span");
    statusDot.className = "status-dot";
    statusDot.dataset.status = status;
    statusContainer.appendChild(statusDot);

    // Status text with proper capitalization
    const statusText = document.createElement("span");
    statusText.className = "status-text";
    statusText.textContent = this.formatStatus(status);
    statusContainer.appendChild(statusText);

    secondaryRow.appendChild(statusContainer);

    // Add a placeholder for right alignment to match customer name row layout
    const placeholder = document.createElement("span");
    placeholder.className = "placeholder";
    secondaryRow.appendChild(placeholder);

    return secondaryRow;
  }
}

class PaymentRowComponent {
  static formatPaymentStatus(paymentStatus) {
    return paymentStatus
      .replace(/_/g, " ")
      .split(" ")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
      .join(" ");
  }

  static render(paymentStatus, totalCost) {
    // Container with separator line
    const paymentContainer = document.createElement("div");
    paymentContainer.className = "payment-container";

    // Add separator line
    const separator = document.createElement("div");
    separator.className = "payment-separator";
    paymentContainer.appendChild(separator);

    // Payment row
    const paymentRow = document.createElement("div");
    paymentRow.className = "payment-row";

    // First show amount, then status
    // Amount on the left
    if (totalCost) {
      const costEl = document.createElement("span");
      costEl.className = "order-cost";
      costEl.textContent = `$${totalCost}`;
      paymentRow.appendChild(costEl);
    } else {
      // Add a placeholder for alignment
      const placeholder = document.createElement("span");
      placeholder.className = "placeholder";
      paymentRow.appendChild(placeholder);
    }

    // Payment status text without icon - right-aligned
    const paymentStatusText = document.createElement("span");
    paymentStatusText.className = "payment-status-text";
    paymentStatusText.textContent = this.formatPaymentStatus(paymentStatus);
    paymentRow.appendChild(paymentStatusText);

    paymentContainer.appendChild(paymentRow);
    return paymentContainer;
  }
}

class EventContentComponent {
  static render(info) {
    const orderData = info.event.extendedProps.order;
    const customerData = info.event.extendedProps.customer;

    // Container for the entire content - Notion card style
    const container = document.createElement("div");
    container.className = "event-container";
    container.dataset.status = orderData.status;

    // Time row with status on the right - layout now shows hour and status in same row
    if (info.timeText) {
      container.appendChild(
        EventTimeComponent.render(info.timeText, orderData.status),
      );
    }

    // Customer Name row - just the name with no other elements
    container.appendChild(CustomerNameComponent.render(customerData.name));

    // Payment row - amount on left, payment status on right
    container.appendChild(
      PaymentRowComponent.render(
        orderData.payment_status,
        orderData.total_cost,
      ),
    );

    return { domNodes: [container] };
  }
}

// Helper functions
const processEvents = (events, statusColors) => {
  return events.map((event) => {
    // Using white background with colored left border for Notion-style
    return {
      ...event,
      backgroundColor: "#ffffff",
      borderColor:
        statusColors[event.extendedProps.order.status] ||
        statusColors.unconfirmed,
      textColor: "#37352f",
    };
  });
};

// Main component
const OrderCalendar = {
  mounted() {
    const calendarEl = this.el;
    const orderEvents = JSON.parse(calendarEl.dataset.events || "[]");
    const initialView = calendarEl.dataset.view || "listMonth";

    // Process events to add status colors
    const processedEvents = processEvents(orderEvents, STATUS_COLORS);

    // Create calendar container
    const calendarContainer = document.createElement("div");
    calendarContainer.className = "calendar-container";
    calendarEl.appendChild(calendarContainer);

    // Initialize the calendar
    this.calendar = new Calendar({
      target: calendarContainer,
      props: {
        plugins: [TimeGrid, ListView, DayGrid],
        options: {
          view: initialView,
          events: processedEvents,
          // Notion-style event display
          eventContent: (info) => EventContentComponent.render(info),
          eventClick: (info) => {
            this.pushEvent("show_event_modal", {
              eventId: info.event.id,
            });
            return false;
          },
          datesSet: (info) => {
            const startDate = info.start.toISOString().split("T")[0];
            const endDate = info.end.toISOString().split("T")[0];
            const viewType = info.view.type;

            this.pushEvent("update_date_filters", {
              start_date: startDate,
              end_date: endDate,
              view_type: viewType,
            });
          },
          // Standard header toolbar without custom buttons
          headerToolbar: {
            start: "title",
            center: "",
            end: "today prev,next",
          },
        },
      },
    });
  },

  updated() {
    if (this.calendar) {
      const orderEvents = JSON.parse(this.el.dataset.events || "[]");
      const currentView = this.el.dataset.view || "listMonth";

      // Process events to add status colors
      const processedEvents = processEvents(orderEvents, STATUS_COLORS);

      // Update the calendar with new events and view
      this.calendar.$set({
        options: {
          events: processedEvents,
          view: currentView,
        },
      });
    }
  },

  destroyed() {
    if (this.calendar) {
      this.calendar.$destroy();
    }
  },
};

export default OrderCalendar;
