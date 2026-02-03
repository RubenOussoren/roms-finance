import { Controller } from "@hotwired/stimulus";
import * as d3 from "d3";

/**
 * Base controller for D3.js charts with shared functionality:
 * - SVG and group setup with margin handling
 * - Responsive resize observer with debouncing
 * - Tooltip positioning with overflow handling
 * - Scale creation utilities
 * - Throttle utility for event handlers
 */
export default class BaseD3ChartController extends Controller {
  static values = {
    data: Object,
  };

  _d3SvgMemo = null;
  _d3GroupMemo = null;
  _d3Tooltip = null;
  _d3InitialContainerWidth = 0;
  _d3InitialContainerHeight = 0;
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

    this._d3Container.selectAll("*").remove();
  }

  _install() {
    this._normalizeDataPoints();
    this._rememberInitialContainerSize();
    this._draw();
  }

  // Override in subclass to normalize data
  _normalizeDataPoints() {
    throw new Error("Subclass must implement _normalizeDataPoints()");
  }

  _rememberInitialContainerSize() {
    this._d3InitialContainerWidth = this._d3Container.node().clientWidth;
    this._d3InitialContainerHeight = this._d3Container.node().clientHeight;
  }

  // Override in subclass to implement drawing logic
  _draw() {
    throw new Error("Subclass must implement _draw()");
  }

  _drawEmpty(message = "No data available") {
    this._d3Svg.selectAll(".tick").remove();
    this._d3Svg.selectAll(".domain").remove();

    this._d3Svg
      .append("text")
      .attr("x", this._d3InitialContainerWidth / 2)
      .attr("y", this._d3InitialContainerHeight / 2)
      .attr("text-anchor", "middle")
      .attr("class", "fg-subdued")
      .style("font-size", "14px")
      .text(message);
  }

  _drawTooltip() {
    this._d3Tooltip = d3
      .select(`#${this.element.id}`)
      .append("div")
      .attr(
        "class",
        "bg-container text-sm font-sans absolute p-2 border border-secondary rounded-lg pointer-events-none opacity-0",
      )
      .attr("role", "tooltip");
  }

  /**
   * Position tooltip with smart overflow handling
   * @param {MouseEvent} event - Mouse event for positioning
   * @param {string} content - HTML content for tooltip
   */
  _positionTooltip(event, content) {
    // Render content first to get dimensions
    this._d3Tooltip.html(content).style("opacity", 1);

    const tooltipNode = this._d3Tooltip.node();
    const tooltipRect = tooltipNode.getBoundingClientRect();
    const tooltipWidth = tooltipRect.width;
    const tooltipHeight = tooltipRect.height;

    // Get viewport and page dimensions
    const pageWidth = document.documentElement.clientWidth;
    const pageHeight = document.documentElement.clientHeight;
    const scrollY = window.scrollY;

    // Calculate positions with overflow handling
    const padding = 10;
    let tooltipX = event.pageX + padding;
    let tooltipY = event.pageY - padding;

    // Horizontal overflow: flip to left side if needed
    if (tooltipX + tooltipWidth > pageWidth - padding) {
      tooltipX = event.pageX - tooltipWidth - padding;
    }
    // Ensure it doesn't go off the left edge
    tooltipX = Math.max(padding, tooltipX);

    // Vertical overflow: position below cursor if needed
    if (tooltipY - tooltipHeight < scrollY + padding) {
      tooltipY = event.pageY + padding + tooltipHeight;
    }
    // Ensure it doesn't go off the bottom
    if (tooltipY > scrollY + pageHeight - padding) {
      tooltipY = scrollY + pageHeight - padding;
    }

    this._d3Tooltip
      .style("z-index", 999)
      .style("left", `${tooltipX}px`)
      .style("top", `${tooltipY - tooltipHeight}px`);
  }

  _hideTooltip() {
    this._d3Tooltip?.style("opacity", 0);
  }

  _createGuideline() {
    this._guideline = this._d3Group
      .append("line")
      .attr("class", "guideline fg-subdued")
      .attr("y1", 0)
      .attr("y2", this._d3ContainerHeight)
      .attr("stroke", "currentColor")
      .attr("stroke-dasharray", "4, 4")
      .style("opacity", 0);
  }

  _createDataCircle(radius = 5) {
    this._dataCircle = this._d3Group
      .append("circle")
      .attr("class", "data-point-circle")
      .attr("r", radius)
      .attr("pointer-events", "none")
      .style("opacity", 0);
  }

  _createInteractionRect(onMouseMove, onMouseOut) {
    this._d3Group
      .append("rect")
      .attr("class", "bg-container")
      .attr("width", this._d3ContainerWidth)
      .attr("height", this._d3ContainerHeight)
      .attr("fill", "none")
      .attr("pointer-events", "all")
      .on("mousemove", this._throttle(onMouseMove, 50))
      .on("mouseout", onMouseOut);
  }

  _showGuideline(xPos) {
    this._guideline
      .attr("x1", xPos)
      .attr("x2", xPos)
      .style("opacity", 1);
  }

  _hideGuideline() {
    this._guideline?.style("opacity", 0);
  }

  _showDataCircle(cx, cy, color) {
    this._dataCircle
      .attr("cx", cx)
      .attr("cy", cy)
      .attr("fill", color)
      .style("opacity", 1);
  }

  _hideDataCircle() {
    this._dataCircle?.style("opacity", 0);
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
      ])
      .attr("role", "img")
      .attr("aria-label", this._chartAriaLabel);
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

  // Override in subclass for custom aria label
  get _chartAriaLabel() {
    return "Chart";
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

  /**
   * Create a time scale for dates
   * @param {Date[]} dates - Array of dates
   * @returns {d3.ScaleTime} D3 time scale
   */
  _createTimeScale(dates) {
    return d3
      .scaleTime()
      .rangeRound([0, this._d3ContainerWidth])
      .domain(d3.extent(dates));
  }

  /**
   * Create a linear scale for values with automatic domain calculation
   * @param {number[]} values - Array of values
   * @param {Object} options - Scale options
   * @param {boolean} options.allowNegative - Allow negative values in domain (default: true)
   * @param {number} options.paddingPercent - Padding as percentage of range (default: 0.1)
   * @returns {d3.ScaleLinear} D3 linear scale
   */
  _createLinearScale(values, options = {}) {
    const { allowNegative = true, paddingPercent = 0.1 } = options;

    const dataMin = d3.min(values);
    const dataMax = d3.max(values);

    // Handle edge case where all values are the same
    if (dataMin === dataMax) {
      const padding = dataMax === 0 ? 100 : Math.abs(dataMax) * 0.5;
      return d3
        .scaleLinear()
        .rangeRound([this._d3ContainerHeight, 0])
        .domain([dataMin - padding, dataMax + padding]);
    }

    const dataRange = dataMax - dataMin;
    const padding = dataRange * paddingPercent;

    // Handle negative values appropriately
    let domainMin;
    if (allowNegative) {
      domainMin = dataMin >= 0 && dataMin < dataRange * 0.2
        ? 0
        : dataMin - padding;
    } else {
      domainMin = Math.max(0, dataMin - padding);
    }

    return d3
      .scaleLinear()
      .rangeRound([this._d3ContainerHeight, 0])
      .domain([domainMin, dataMax + padding]);
  }

  /**
   * Format currency value
   * @param {number} value - Value to format
   * @param {string} currency - Currency code (default: "USD")
   * @returns {string} Formatted currency string
   */
  _formatCurrency(value, currency = "USD") {
    return new Intl.NumberFormat("en-US", {
      style: "currency",
      currency: currency,
      minimumFractionDigits: 0,
      maximumFractionDigits: 0,
    }).format(value);
  }
}

// Re-export d3 for convenience in subclasses
export { d3 };
