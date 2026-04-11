import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="equity-grant-form"
export default class extends Controller {
  static targets = ["grantType", "optionFields"];

  toggleOptionFields() {
    const isOption = this.grantTypeTarget.value === "stock_option";
    this.optionFieldsTarget.classList.toggle("hidden", !isOption);
  }
}
