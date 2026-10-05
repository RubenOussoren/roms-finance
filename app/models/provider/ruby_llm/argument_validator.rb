# Validates the JSON Schema subset used by Assistant::Function before execution.
# RubyLLM validates Ruby keyword signatures, not JSON value types/constraints.
# Unsupported schema keywords fail at registration rather than silently permitting
# arguments that have not been validated. This is not a general JSON Schema engine.
class Provider::RubyLlm::ArgumentValidator
  KEYWORDS = %w[type properties required additionalProperties items enum minItems uniqueItems description].freeze
  TYPES = %w[object array string integer number boolean null].freeze

  def initialize(schema)
    @schema = schema.deep_stringify_keys
    check_schema!(@schema)
  end

  def errors(arguments)
    validate(arguments, @schema, "$")
  end

  private
    def check_schema!(schema)
      unknown = schema.keys - KEYWORDS
      raise ArgumentError, "Unsupported tool schema keywords: #{unknown.join(', ')}" if unknown.any?
      if schema.key?("type") && !TYPES.include?(schema["type"])
        raise ArgumentError, "Unsupported tool schema type: #{schema['type']}"
      end

      properties = schema.fetch("properties", {})
      if (schema.fetch("required", []) - properties.keys).any?
        raise ArgumentError, "Required tool arguments must be declared properties"
      end
      if schema.key?("additionalProperties") && ![ true, false ].include?(schema["additionalProperties"])
        raise ArgumentError, "Only boolean additionalProperties is supported"
      end
      properties.each_value { |definition| check_schema!(definition) }
      check_schema!(schema["items"]) if schema.key?("items")
    end

    def validate(value, schema, path)
      if schema.key?("type") && !matches_type?(value, schema["type"])
        return [ detail(path, "must be #{schema['type']}") ]
      end

      errors = []
      if schema.key?("enum") && !schema["enum"].include?(value)
        errors << detail(path, "must be an allowed value")
      end

      case value
      when Hash
        properties = schema.fetch("properties", {})
        schema.fetch("required", []).each do |name|
          errors << detail("#{path}.#{name}", "is required") unless value.key?(name)
        end
        value.each do |name, item|
          if properties.key?(name)
            errors.concat(validate(item, properties[name], "#{path}.#{name}"))
          elsif schema["additionalProperties"] == false
            errors << detail("#{path}.#{name}", "is not allowed")
          end
        end
      when Array
        if schema.key?("minItems") && value.length < schema["minItems"]
          errors << detail(path, "must contain at least #{schema['minItems']} items")
        end
        errors << detail(path, "must contain unique items") if schema["uniqueItems"] && value.uniq.length != value.length
        if schema.key?("items")
          value.each_with_index { |item, index| errors.concat(validate(item, schema["items"], "#{path}[#{index}]")) }
        end
      end
      errors
    end

    def matches_type?(value, type)
      case type
      when "object" then value.is_a?(Hash)
      when "array" then value.is_a?(Array)
      when "string" then value.is_a?(String)
      when "number" then json_number?(value)
      when "integer" then json_number?(value) && value == value.to_i
      when "boolean" then value == true || value == false
      when "null" then value.nil?
      end
    end

    def json_number?(value)
      value.is_a?(Numeric) && value.real? && value.finite?
    end

    def detail(path, message)
      { path: path, message: message }
    end
end
