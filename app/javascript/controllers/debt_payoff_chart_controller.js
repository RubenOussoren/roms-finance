import BaseD3ChartController, { d3 } from "controllers/base_d3_chart";

const parseLocalDate = d3.timeParse("%Y-%m-%d");

export default class extends BaseD3ChartController {
  _historicalDataPoints = [];
  _projectionDataPoints = [];

  _teardown() {
    super._teardown();
    this._historicalDataPoints = [];
    this._projectionDataPoints = [];
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

  _draw() {
    if (this._historicalDataPoints.length < 1 && this._projectionDataPoints.length < 1) {
      this._drawEmpty("No debt payoff data available");
    } else {
      this._drawChart();
    }
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

    this._createGuideline();
    this._createDataCircle();

    this._createInteractionRect(
      (event) => {
        const [xPos] = d3.pointer(event);
        const x0 = bisectDate(allDataPoints, this._d3XScale.invert(xPos), 1);
        const d0 = allDataPoints[Math.max(0, x0 - 1)];
        const d1 = allDataPoints[Math.min(allDataPoints.length - 1, x0)];

        if (!d0 || !d1) return;

        const d =
          xPos - this._d3XScale(d0.date) > this._d3XScale(d1.date) - xPos ? d1 : d0;

        // Update guideline position and show it
        this._showGuideline(this._d3XScale(d.date));

        // Update circle position, color, and show it
        const circleColor =
          d.type === "historical" ? "var(--color-gray-400)" : "var(--color-blue-500)";

        this._showDataCircle(this._d3XScale(d.date), this._d3YScale(d.value), circleColor);

        // Render tooltip with smart positioning
        this._positionTooltip(event, this._tooltipTemplate(d));
      },
      (event) => {
        const hoveringOnGuideline = event.toElement?.classList.contains("guideline");

        if (!hoveringOnGuideline) {
          this._hideGuideline();
          this._hideDataCircle();
          this._hideTooltip();
        }
      }
    );
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

  get _chartAriaLabel() {
    return "Debt payoff chart showing remaining balance over time";
  }

  get _d3XScale() {
    const allDates = [
      ...this._historicalDataPoints.map((d) => d.date),
      ...this._projectionDataPoints.map((d) => d.date),
    ];

    return this._createTimeScale(allDates);
  }

  get _d3YScale() {
    const historicalValues = this._historicalDataPoints.map((d) => d.value);
    const projectionValues = this._projectionDataPoints.map((d) => d.value);
    const allValues = [...historicalValues, ...projectionValues];

    // Debt values are positive (absolute balance), so don't allow negative
    return this._createLinearScale(allValues, { allowNegative: false });
  }
}
