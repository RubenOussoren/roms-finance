---
name: stimulus
description: Create a new Stimulus controller (global or component-specific)
---

# Create Stimulus Controller

Generate a new Stimulus controller following project conventions.

## Usage

```
/stimulus toggle                        # Global controller
/stimulus dropdown --global             # Explicit global controller
/stimulus CardComponent tooltip         # Component-specific controller
```

## Controller Locations

### Global Controllers
Location: `app/javascript/controllers/`
- Used across multiple views/components
- Registered automatically via manifest

### Component Controllers
Location: `app/components/[component_name]/[name]_controller.js`
- Used only within a specific component
- Scoped to component functionality

## Controller Template

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "content"]
  static values = {
    open: { type: Boolean, default: false }
  }

  connect() {
    // Initialize
  }

  toggle() {
    this.openValue = !this.openValue
  }

  openValueChanged() {
    this.contentTarget.classList.toggle("hidden", !this.openValue)
  }
}
```

## Instructions

1. Determine controller type (global vs component-specific)
2. Generate controller in appropriate location
3. Include basic structure with targets and values
4. Follow declarative action pattern

## Declarative Actions (Required)

```erb
<!-- GOOD: Declarative - HTML declares what happens -->
<div data-controller="toggle">
  <button data-action="click->toggle#toggle" data-toggle-target="button">
    Show
  </button>
  <div data-toggle-target="content" class="hidden">
    Hello World!
  </div>
</div>
```

## Best Practices

- Keep controllers lightweight (< 7 targets)
- Use private methods, expose clear public API
- Single responsibility or highly related responsibilities
- Pass data via `data-*-value` attributes, not inline JavaScript
- Use `static targets` and `static values` for reactivity

## Important Notes

- Controller names are kebab-case in HTML: `data-controller="my-controller"`
- Method names should be clear action verbs: `toggle`, `open`, `close`, `submit`
- Avoid DOM manipulation outside Stimulus lifecycle
