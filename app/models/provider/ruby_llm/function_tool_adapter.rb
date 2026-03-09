# Converts Assistant::Function instances into RubyLLM::Tool subclasses
# so they can be registered with RubyLLM.chat.with_tool(ToolClass)
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
      fn_schema = function_instance.params_schema || {}
      fn_instance = function_instance

      Class.new(::RubyLLM::Tool) do
        description fn_description

        # Define parameters from the JSON schema
        if fn_schema[:properties].present?
          fn_schema[:properties].each do |prop_name, prop_def|
            required = fn_schema[:required]&.include?(prop_name.to_s)
            param prop_name,
                  type: :string,
                  desc: prop_def[:description] || "",
                  required: required
          end
        end

        # Override name to use the function's name (e.g., "get_accounts")
        define_method(:name) { fn_name }

        define_method(:execute) do |**kwargs|
          # Convert keyword args to string-keyed hash matching existing function interface
          string_args = kwargs.transform_keys(&:to_s)
          result = fn_instance.call(string_args)

          # Log for persistence
          log << { function_name: fn_name, arguments: string_args, result: result }

          result
        end
      end
    end
end
