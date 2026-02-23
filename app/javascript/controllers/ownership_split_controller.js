import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="ownership-split"
export default class extends Controller {
  static targets = ["percentage", "unassigned", "error", "submit"]

  connect() {
    this.recalculate()
  }

  recalculate() {
    let total = 0
    this.percentageTargets.forEach((input) => {
      const val = Number.parseFloat(input.value)
      if (!Number.isNaN(val)) total += val
    })

    const unassigned = Math.max(0, 100 - total)
    this.unassignedTarget.textContent = `${unassigned.toFixed(2)}%`

    if (total > 100) {
      this.errorTarget.classList.remove("hidden")
      this.submitTarget.disabled = true
    } else {
      this.errorTarget.classList.add("hidden")
      this.submitTarget.disabled = false
    }
  }
}
