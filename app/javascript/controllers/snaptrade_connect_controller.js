import { Controller } from "@hotwired/stimulus"

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
      window.location.href = `${this.callbackUrlValue}?authorizationId=${encodeURIComponent(data.authorizationId)}`
    } else if (data?.status === "ERROR") {
      window.location.href = "/accounts"
    } else if (data === "CLOSE_MODAL" || data === "CLOSED") {
      window.location.href = "/accounts"
    }
  }
}
