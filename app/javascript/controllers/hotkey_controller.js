import { install, uninstall } from "@github/hotkey";
import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="hotkey"
export default class extends Controller {
  connect() {
    install(this.element);
  }

  disconnect() {
    uninstall(this.element);
  }

  navigateBack(_event) {
    window.history.back();
  }
}
