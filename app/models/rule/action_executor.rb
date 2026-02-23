class Rule::ActionExecutor
  TYPES = [ "select", "function", "text" ]

  def initialize(rule)
    @rule = rule
  end

  def key
    self.class.name.demodulize.underscore
  end

  def label
    key.humanize
  end

  def type
    "function"
  end

  def preposition
    "to"
  end

  def options
    nil
  end

  def execute(scope, value: nil, ignore_attribute_locks: false)
    raise NotImplementedError, "Action executor #{self.class.name} must implement #execute"
  end

  def as_json
    {
      type: type,
      key: key,
      label: label,
      options: options,
      preposition: preposition
    }
  end

  private
    attr_reader :rule

    def family
      rule.family
    end
end
