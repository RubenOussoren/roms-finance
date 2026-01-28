import { Controller } from "@hotwired/stimulus"
import * as d3 from "d3"

// 🇨🇦 Debt comparison chart for Smith Manoeuvre visualization
export default class extends Controller {
  static values = {
    series: Object,
    hasBaseline: Boolean
  }

  _resizeTimeout = null

  connect() {
    this.drawChart()
    this._boundHandleResize = this.handleResize.bind(this)
    window.addEventListener("resize", this._boundHandleResize)
  }

  disconnect() {
    window.removeEventListener("resize", this._boundHandleResize)
    clearTimeout(this._resizeTimeout)
  }

  handleResize() {
    // Debounce resize to prevent freeze during sidebar toggle
    clearTimeout(this._resizeTimeout)
    this._resizeTimeout = setTimeout(() => this.drawChart(), 150)
  }

  drawChart() {
    const container = this.element
    container.innerHTML = ""

    const series = this.seriesValue
    if (!series || Object.keys(series).length === 0) {
      container.innerHTML = '<div class="flex items-center justify-center h-full text-secondary">No data available</div>'
      return
    }

    const margin = { top: 20, right: 30, bottom: 30, left: 60 }
    const width = container.clientWidth - margin.left - margin.right
    const height = container.clientHeight - margin.top - margin.bottom

    const svg = d3.select(container)
      .append("svg")
      .attr("width", width + margin.left + margin.right)
      .attr("height", height + margin.top + margin.bottom)
      .append("g")
      .attr("transform", `translate(${margin.left},${margin.top})`)

    // Combine all data points to get x/y domains
    let allData = []
    if (series.baseline) allData = allData.concat(series.baseline)
    if (series.strategy) allData = allData.concat(series.strategy)

    if (allData.length === 0) {
      container.innerHTML = '<div class="flex items-center justify-center h-full text-secondary">No data available</div>'
      return
    }

    // Parse dates
    const parseDate = d3.timeParse("%Y-%m-%d")
    allData.forEach(d => {
      d.parsedDate = parseDate(d.date)
    })

    // Scales
    const x = d3.scaleTime()
      .domain(d3.extent(allData, d => d.parsedDate))
      .range([0, width])

    const y = d3.scaleLinear()
      .domain([0, d3.max(allData, d => d.value) * 1.1])
      .range([height, 0])

    // Line generator
    const line = d3.line()
      .x(d => x(d.parsedDate))
      .y(d => y(d.value))
      .curve(d3.curveMonotoneX)

    // Draw baseline (gray dashed line)
    if (this.hasBaselineValue && series.baseline) {
      const baselineData = series.baseline.map(d => ({
        ...d,
        parsedDate: parseDate(d.date)
      }))

      svg.append("path")
        .datum(baselineData)
        .attr("fill", "none")
        .attr("stroke", "#9CA3AF")
        .attr("stroke-width", 2)
        .attr("stroke-dasharray", "5,5")
        .attr("d", line)
    }

    // Draw strategy line (blue solid line)
    if (series.strategy) {
      const strategyData = series.strategy.map(d => ({
        ...d,
        parsedDate: parseDate(d.date)
      }))

      svg.append("path")
        .datum(strategyData)
        .attr("fill", "none")
        .attr("stroke", "#3B82F6")
        .attr("stroke-width", 2)
        .attr("d", line)
    }

    // X axis
    svg.append("g")
      .attr("transform", `translate(0,${height})`)
      .call(d3.axisBottom(x).ticks(6).tickFormat(d3.timeFormat("%b %Y")))
      .selectAll("text")
      .attr("class", "text-xs text-secondary")

    // Y axis
    svg.append("g")
      .call(d3.axisLeft(y).ticks(5).tickFormat(d => this.formatCurrency(d)))
      .selectAll("text")
      .attr("class", "text-xs text-secondary")

    // Grid lines
    svg.append("g")
      .attr("class", "grid")
      .attr("opacity", 0.1)
      .call(d3.axisLeft(y)
        .ticks(5)
        .tickSize(-width)
        .tickFormat("")
      )
  }

  formatCurrency(value) {
    if (value >= 1000000) {
      return `$${(value / 1000000).toFixed(1)}M`
    } else if (value >= 1000) {
      return `$${(value / 1000).toFixed(0)}K`
    }
    return `$${value.toFixed(0)}`
  }
}
