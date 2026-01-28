import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

const parseLocalDate = d3.timeParse("%Y-%m-%d");

export default class extends Controller {
  static values = {
    data: Object,
  };

  _d3SvgMemo = null;
  _d3GroupMemo = null;
  _d3Tooltip = null;
  _d3InitialContainerWidth = 0;
  _d3InitialContainerHeight = 0;
  _historicalDataPoints = [];
  _projectionDataPoints = [];
  _resizeObserver = null;
  _resizeTimeout = null;
  _guideline = null;
  _dataCircle = null;

  connect() {
    this._install();
    document.addEventListener("turbo:load", this._reinstall);
    this._setupResizeObserver();
  }

  disconnect() {
    this._teardown();
    document.removeEventListener("turbo:load", this._reinstall);
    this._resizeObserver?.disconnect();
  }

  _reinstall = () => {
    this._teardown();
    this._install();
  };

  _teardown() {
    this._d3SvgMemo = null;
    this._d3GroupMemo = null;
    this._d3Tooltip = null;
    this._historicalDataPoints = [];
    this._projectionDataPoints = [];

    this._d3Container.selectAll("*").remove();
  }

  _install() {
    this._normalizeDataPoints();
    this._rememberInitialContainerSize();
    this._draw();
  }

  _normalizeDataPoints() {
    this._historicalDataPoints = (this.dataValue.historical || []).map((d) => ({
      date: parseLocalDate(d.date),
      value: d.value,
    }));

    this._projectionDataPoints = (this.dataValue.projections || []).map((d) => ({
      date: parseLocalDate(d.date),
      value: d.value,
    }));
  }

  _rememberInitialContainerSize() {
    this._d3InitialContainerWidth = this._d3Container.node().clientWidth;
    this._d3InitialContainerHeight = this._d3Container.node().clientHeight;
  }

  _draw() {
    if (this._historicalDataPoints.length < 1 && this._projectionDataPoints.length < 1) {
      this._drawEmpty();
    } else {
      this._drawChart();
    }
  }

  _drawEmpty() {
    this._d3Svg.selectAll(".tick").remove();
    this._d3Svg.selectAll(".domain").remove();

    this._d3Svg
      .append("text")
      .attr("x", this._d3InitialContainerWidth / 2)
      .attr("y", this._d3InitialContainerHeight / 2)
      .attr("text-anchor", "middle")
      .attr("class", "fg-subdued")
      .style("font-size", "14px")
      .text("No debt payoff data available");
  }

  _drawChart() {
    // Draw historical line (solid gray)
    this._drawHistoricalLine();

    // Draw projection line (dashed blue)
    this._drawProjectionLine();

    // Draw today divider line
    this._drawTodayLine();

    // Draw X axis labels
    this._drawXAxisLabels();

    // Draw tooltip tracking
    this._drawTooltip();
    this._trackMouseForShowingTooltip();
  }

  _drawHistoricalLine() {
    if (this._historicalDataPoints.length < 2) return;

    const line = d3
      .line()
      .x((d) => this._d3XScale(d.date))
      .y((d) => this._d3YScale(d.value));

    this._d3Group
      .append("path")
      .datum(this._historicalDataPoints)
      .attr("fill", "none")
      .attr("stroke", "var(--color-gray-400)")
      .attr("stroke-width", 2)
      .attr("stroke-linejoin", "round")
      .attr("stroke-linecap", "round")
      .attr("d", line);
  }

  _drawProjectionLine() {
    if (this._projectionDataPoints.length < 2) return;

    const line = d3
      .line()
      .x((d) => this._d3XScale(d.date))
      .y((d) => this._d3YScale(d.value));

    this._d3Group
      .append("path")
      .datum(this._projectionDataPoints)
      .attr("fill", "none")
      .attr("stroke", "var(--color-blue-500)")
      .attr("stroke-width", 2)
      .attr("stroke-dasharray", "6, 4")
      .attr("stroke-linejoin", "round")
      .attr("stroke-linecap", "round")
      .attr("d", line);
  }

  _drawTodayLine() {
    const todayStr = this.dataValue.today;
    if (!todayStr) return;

    const today = parseLocalDate(todayStr);
    const xPos = this._d3XScale(today);

    this._d3Group
      .append("line")
      .attr("class", "today-line")
      .attr("x1", xPos)
      .attr("y1", 0)
      .attr("x2", xPos)
      .attr("y2", this._d3ContainerHeight)
      .attr("stroke", "var(--color-gray-300)")
      .attr("stroke-width", 1)
      .attr("stroke-dasharray", "4, 4");

    // Label for "Today"
    this._d3Group
      .append("text")
      .attr("x", xPos)
      .attr("y", -5)
      .attr("text-anchor", "middle")
      .attr("class", "fg-subdued")
      .style("font-size", "10px")
      .text("Today");
  }

  _drawXAxisLabels() {
    const allDates = [
      ...this._historicalDataPoints.map((d) => d.date),
      ...this._projectionDataPoints.map((d) => d.date),
    ];

    if (allDates.length < 2) return;

    const firstDate = allDates[0];
    const lastDate = allDates[allDates.length - 1];

    this._d3Group
      .append("g")
      .attr("transform", `translate(0,${this._d3ContainerHeight})`)
      .call(
        d3
          .axisBottom(this._d3XScale)
          .tickValues([firstDate, lastDate])
          .tickSize(0)
          .tickFormat(d3.timeFormat("%b %Y")),
      )
      .select(".domain")
      .remove();

    this._d3Group
      .selectAll(".tick text")
      .attr("class", "fg-gray")
      .style("font-size", "12px")
      .style("font-weight", "500")
      .attr("text-anchor", "middle")
      .attr("dx", (_d, i) => (i === 0 ? "3em" : "-3em"))
      .attr("dy", "0em");
  }

  _drawTooltip() {
    this._d3Tooltip = d3
      .select(`#${this.element.id}`)
      .append("div")
      .attr(
        "class",
        "bg-container text-sm font-sans absolute p-2 border border-secondary rounded-lg pointer-events-none opacity-0",
      );
  }

  _trackMouseForShowingTooltip() {
    const allDataPoints = [
      ...this._historicalDataPoints.map((d) => ({
        date: d.date,
        type: "historical",
        value: d.value,
      })),
      ...this._projectionDataPoints.map((d) => ({
        date: d.date,
        type: "projection",
        value: d.value,
      })),
    ].sort((a, b) => a.date - b.date);

    const bisectDate = d3.bisector((d) => d.date).left;

    // Create reusable DOM elements once (toggle opacity instead of remove/add)
    this._guideline = this._d3Group
      .append("line")
      .attr("class", "guideline fg-subdued")
      .attr("y1", 0)
      .attr("y2", this._d3ContainerHeight)
      .attr("stroke", "currentColor")
      .attr("stroke-dasharray", "4, 4")
      .style("opacity", 0);

    this._dataCircle = this._d3Group
      .append("circle")
      .attr("class", "data-point-circle")
      .attr("r", 5)
      .attr("pointer-events", "none")
      .style("opacity", 0);

    this._d3Group
      .append("rect")
      .attr("class", "bg-container")
      .attr("width", this._d3ContainerWidth)
      .attr("height", this._d3ContainerHeight)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("mousemove", this._throttle((event) => {
        const estimatedTooltipWidth = 200;
        const pageWidth = document.body.clientWidth;
        const tooltipX = event.pageX + 10;
        const overflowX = tooltipX + estimatedTooltipWidth - pageWidth;
        const adjustedX = overflowX > 0 ? event.pageX - overflowX - 20 : tooltipX;

        const [xPos] = d3.pointer(event);
        const x0 = bisectDate(allDataPoints, this._d3XScale.invert(xPos), 1);
        const d0 = allDataPoints[Math.max(0, x0 - 1)];
        const d1 = allDataPoints[Math.min(allDataPoints.length - 1, x0)];

        if (!d0 || !d1) return;

        const d =
          xPos - this._d3XScale(d0.date) > this._d3XScale(d1.date) - xPos ? d1 : d0;

        // Update guideline position and show it
        this._guideline
          .attr("x1", this._d3XScale(d.date))
          .attr("x2", this._d3XScale(d.date))
          .style("opacity", 1);

        // Update circle position, color, and show it
        const circleColor =
          d.type === "historical" ? "var(--color-gray-400)" : "var(--color-blue-500)";

        this._dataCircle
          .attr("cx", this._d3XScale(d.date))
          .attr("cy", this._d3YScale(d.value))
          .attr("fill", circleColor)
          .style("opacity", 1);

        // Render tooltip
        this._d3Tooltip
          .html(this._tooltipTemplate(d))
          .style("opacity", 1)
          .style("z-index", 999)
          .style("left", `${adjustedX}px`)
          .style("top", `${event.pageY - 10}px`);
      }, 50)) // 50ms = 20 updates/sec max
      .on("mouseout", (event) => {
        const hoveringOnGuideline = event.toElement?.classList.contains("guideline");

        if (!hoveringOnGuideline) {
          // Hide elements instead of removing them
          this._guideline.style("opacity", 0);
          this._dataCircle.style("opacity", 0);
          this._d3Tooltip.style("opacity", 0);
        }
      });
  }

  _tooltipTemplate(datum) {
    const dateFormatted = d3.timeFormat("%b %d, %Y")(datum.date);
    const currency = this.dataValue.currency || "USD";

    if (datum.type === "historical") {
      return `
        <div style="margin-bottom: 4px; color: var(--color-gray-500);">
          ${dateFormatted}
        </div>
        <div class="text-primary">
          ${this._formatCurrency(datum.value, currency)}
        </div>
      `;
    }

    return `
      <div style="margin-bottom: 4px; color: var(--color-gray-500);">
        ${dateFormatted} <span class="text-blue-500">(projected)</span>
      </div>
      <div class="text-primary">
        ${this._formatCurrency(datum.value, currency)}
      </div>
    `;
  }

  _formatCurrency(value, currency) {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value);
  }

  _createMainSvg() {
    return this._d3Container
      .append("svg")
      .attr("width", this._d3InitialContainerWidth)
      .attr("height", this._d3InitialContainerHeight)
      .attr("viewBox", [
        0,
        0,
        this._d3InitialContainerWidth,
        this._d3InitialContainerHeight,
      ]);
  }

  _createMainGroup() {
    return this._d3Svg
      .append("g")
      .attr("transform", `translate(${this._margin.left},${this._margin.top})`);
  }

  get _d3Svg() {
    if (!this._d3SvgMemo) {
      this._d3SvgMemo = this._createMainSvg();
    }
    return this._d3SvgMemo;
  }

  get _d3Group() {
    if (!this._d3GroupMemo) {
      this._d3GroupMemo = this._createMainGroup();
    }
    return this._d3GroupMemo;
  }

  get _margin() {
    return { top: 20, right: 0, bottom: 10, left: 0 };
  }

  get _d3ContainerWidth() {
    return this._d3InitialContainerWidth - this._margin.left - this._margin.right;
  }

  get _d3ContainerHeight() {
    return this._d3InitialContainerHeight - this._margin.top - this._margin.bottom;
  }

  get _d3Container() {
    return d3.select(this.element);
  }

  get _d3XScale() {
    const allDates = [
      ...this._historicalDataPoints.map((d) => d.date),
      ...this._projectionDataPoints.map((d) => d.date),
    ];

    return d3
      .scaleTime()
      .rangeRound([0, this._d3ContainerWidth])
      .domain(d3.extent(allDates));
  }

  get _d3YScale() {
    const historicalValues = this._historicalDataPoints.map((d) => d.value);
    const projectionValues = this._projectionDataPoints.map((d) => d.value);
    const allValues = [...historicalValues, ...projectionValues];

    const dataMin = d3.min(allValues);
    const dataMax = d3.max(allValues);

    // Handle edge case where all values are the same
    if (dataMin === dataMax) {
      const padding = dataMax === 0 ? 100 : Math.abs(dataMax) * 0.5;
      return d3
        .scaleLinear()
        .rangeRound([this._d3ContainerHeight, 0])
        .domain([dataMin - padding, dataMax + padding]);
    }

    const dataRange = dataMax - dataMin;
    const padding = dataRange * 0.1;

    return d3
      .scaleLinear()
      .rangeRound([this._d3ContainerHeight, 0])
      .domain([Math.max(0, dataMin - padding), dataMax + padding]);
  }

  _setupResizeObserver() {
    this._resizeObserver = new ResizeObserver(() => {
      // Debounce resize to prevent freeze during sidebar toggle
      clearTimeout(this._resizeTimeout);
      this._resizeTimeout = setTimeout(() => this._reinstall(), 150);
    });
    this._resizeObserver.observe(this.element);
  }

  // Throttle utility to limit event handler frequency
  _throttle(func, limit) {
    let inThrottle;
    return (...args) => {
      if (!inThrottle) {
        func.apply(this, args);
        inThrottle = true;
        setTimeout(() => { inThrottle = false; }, limit);
      }
    };
  }
}
