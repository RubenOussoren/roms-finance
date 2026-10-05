# Converts Assistant::Function instances into RubyLLM::Tool subclasses
# so they can be registered with RubyLLM.chat.with_tools(ToolClass)
#
# RubyLLM calls execute() on each tool automatically when the model requests it.
# The adapter delegates execution to the existing Assistant::Function#call method.
class Provider::RubyLlm::FunctionToolAdapter
  attr_reader :tool_calls_log

  def initialize(function_instances)
    @function_instances = function_instances
    @tool_calls_log = []
  end

  def tool_classes
    @tool_classes ||= function_instances.map { |fn| build_tool_class(fn, tool_calls_log) }
  end

  private
    attr_reader :function_instances

    def build_tool_class(function_instance, log)
      fn_name = function_instance.name
      fn_description = function_instance.description
      fn_schema = function_instance.params_schema || { type: "object", properties: {}, required: [], additionalProperties: false }
      validator = Provider::RubyLlm::ArgumentValidator.new(fn_schema)
      fn_instance = function_instance

      Class.new(::RubyLLM::Tool) do
        description fn_description

        # RubyLLM 2 accepts raw JSON Schema; the single-parameter DSL loses
        # items/enums and other constraints from Assistant::Function schemas.
        parameters fn_schema

        # Override name to use the function's name (e.g., "get_accounts")
        define_method(:name) { fn_name }

        define_method(:execute) do |**kwargs|
          # Convert keyword args to string-keyed hash matching existing function interface
          string_args = kwargs.transform_keys(&:to_s)
          errors = validator.errors(string_args)
          result = if errors.empty?
            fn_instance.call(string_args)
          else
            { error: { type: "invalid_arguments", message: "Correct the arguments to match the tool schema and retry.", details: errors } }
          end

          # Log for persistence
          log << { function_name: fn_name, arguments: string_args, result: result }

          result
        end
      end
    end
end
