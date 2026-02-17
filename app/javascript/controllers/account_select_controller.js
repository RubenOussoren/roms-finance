import { Controller } from "@hotwired/stimulus"

// Manages select-all / deselect-all for the SnapTrade account import form.
export default class extends Controller {
  static targets = ["selectAll", "row", "count"]

  connect() {
    this._updateState()
  }

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this._enabledRows.forEach((cb) => { cb.checked = checked })
    this._updateState()
  }

  toggleRow() {
    this._updateState()
  }

  // --- private ---

  get _enabledRows() {
    return this.rowTargets.filter((cb) => !cb.disabled)
  }

  _updateState() {
    const enabled = this._enabledRows
    const checkedCount = enabled.filter((cb) => cb.checked).length
    const total = enabled.length

    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = total > 0 && checkedCount === total
      this.selectAllTarget.indeterminate = checkedCount > 0 && checkedCount < total
    }

    if (this.hasCountTarget) {
      this.countTarget.textContent = `Import ${checkedCount} of ${total} Account${total === 1 ? "" : "s"}`
    }
  }
}
