import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static values = { callbackUrl: String }

  connect() {
    this.handleMessage = this.handleMessage.bind(this)
    window.addEventListener("message", this.handleMessage)
  }

  disconnect() {
    window.removeEventListener("message", this.handleMessage)
  }

  handleMessage(event) {
    const data = event.data

    if (data?.status === "SUCCESS" && data.authorizationId) {
      Turbo.visit(`${this.callbackUrlValue}?authorizationId=${encodeURIComponent(data.authorizationId)}`)
    } else if (data?.status === "ERROR") {
      Turbo.visit("/accounts")
    } else if (data === "CLOSE_MODAL" || data === "CLOSED") {
      Turbo.visit("/accounts")
    }
  }
}
