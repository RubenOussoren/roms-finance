---
name: component
description: Create a new ViewComponent with template and optional Stimulus controller
---

# Create ViewComponent

Generate a new ViewComponent following project conventions.

## Usage

```
/component DS::Alert                    # Design system component
/component UI::Account::Chart           # Business/feature component
/component DS::Badge --stimulus         # With Stimulus controller
```

## Namespace Convention

Components use two namespaces:
- **`DS::`** — Design system primitives (buttons, alerts, dialogs). Inherit from `DesignSystemComponent`.
- **`UI::`** — Business/feature components (account charts, projection settings). Inherit from `ApplicationComponent`.

Ask which namespace to use if not specified.

## Generated Files

For a `DS::Alert` component:

1. **Component class:** `app/components/DS/alert.rb`
2. **Template:** `app/components/DS/alert.html.erb`
3. **Stimulus controller (optional):** `app/components/DS/alert_controller.js`
4. **Lookbook preview:** `test/components/previews/ds/alert_preview.rb`

For a `UI::Account::Chart` component:

1. **Component class:** `app/components/UI/account/chart.rb`
2. **Template:** `app/components/UI/account/chart.html.erb`

## Component Templates

### DS Component (Design System)
```ruby
# frozen_string_literal: true

class DS::Alert < DesignSystemComponent
  def initialize(attribute:, **options)
    @attribute = attribute
    @options = options
  end

  private

  attr_reader :attribute, :options
end
```

### UI Component (Business)
```ruby
# frozen_string_literal: true

class UI::Account::Chart < ApplicationComponent
  def initialize(attribute:, **options)
    @attribute = attribute
    @options = options
  end

  private

  attr_reader :attribute, :options
end
```

## View Template

```erb
<div class="<%= container_classes %>">
  <%= content %>
</div>
```

## Stimulus Controller Template

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = []
  static values = {}

  connect() {
  }
}
```

## Instructions

1. Parse the component name from arguments (must include `DS::` or `UI::` namespace)
2. If no namespace given, ask the user: DS for design system primitives, UI for business components
3. Determine if Stimulus controller is needed (--stimulus flag)
4. Generate component class: `DS::` inherits from `DesignSystemComponent`, `UI::` inherits from `ApplicationComponent`
5. Generate ERB template using design system tokens
6. If --stimulus, generate Stimulus controller in component directory
7. Generate Lookbook preview matching the namespace

## Design System Requirements

Always use functional tokens from `app/assets/tailwind/maybe-design-system.css`:
- `text-primary` not `text-white`
- `bg-container` not `bg-white`
- `border-primary` not `border-gray-200`

## Icon Usage

Always use the `icon` helper, NEVER `lucide_icon` directly:
```erb
<%= icon("check", class: "w-4 h-4") %>
```

## Important Notes

- Components should have clear, focused responsibilities
- Keep domain logic OUT of view templates
- Prefer components over partials when logic is involved
- Follow existing component patterns in the codebase
