---
name: component
description: Create a new ViewComponent with template and optional Stimulus controller
---

# Create ViewComponent

Generate a new ViewComponent following project conventions.

## Usage

```
/component ButtonComponent              # Basic component
/component CardComponent --stimulus     # With Stimulus controller
/component Modal::DialogComponent       # Namespaced component
```

## Generated Files

For a component named `ExampleComponent`:

1. **Component class:** `app/components/example_component.rb`
2. **Template:** `app/components/example_component.html.erb`
3. **Stimulus controller (optional):** `app/components/example_component/example_component_controller.js`
4. **Lookbook preview:** `test/components/previews/example_component_preview.rb`

## Component Template

```ruby
# frozen_string_literal: true

class ExampleComponent < ApplicationComponent
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

1. Parse the component name from arguments
2. Determine if Stimulus controller is needed (--stimulus flag)
3. Generate component class with proper inheritance
4. Generate ERB template using design system tokens
5. If --stimulus, generate Stimulus controller in component directory
6. Generate Lookbook preview for component development

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
