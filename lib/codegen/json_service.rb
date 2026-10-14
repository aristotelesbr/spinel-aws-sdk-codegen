# frozen_string_literal: true

require_relative 'service'

module Codegen
  # The "json" protocol (such as SSM): a POST of the input as a JSON object,
  # named by the X-Amz-Target header, and a JSON response, as aws-sdk-core's
  # Json::Builder, Json::Parser and Json::Handler do.
  class JsonService < Service
    def initialize(api_path, module_name:, operation_names: nil, in_core: false)
      super
      raise "not a json protocol model: #{metadata['protocol']}" unless metadata['protocol'] == 'json'
    end

    private

    def client_constants
      "  JSON_VERSION = #{metadata['jsonVersion'].inspect}\n  TARGET_PREFIX = #{metadata['targetPrefix'].inspect}\n"
    end

    def transport(name, op)
      target = "\"\#{TARGET_PREFIX}.#{name}\""
      "json = stub ? stub_json(stub, body) : send_json(#{target}, JSON_VERSION, body, #{signed?(op)})\n" \
        "data = Parsers.#{op_method(name)}(json)\n"
    end

    # Shapes reachable from roots through structures, lists and maps: the
    # structures, lists and maps among them, each once.
    def reachable_shapes(roots)
      seen = []
      queue = roots.dup
      until queue.empty?
        name = queue.shift
        next if seen.include?(name)

        s = shape(name)
        next unless %w[structure list map].include?(s['type'])

        seen << name
        case s['type']
        when 'structure' then members(s).each { |m| queue << m[:shape_name] }
        when 'list' then queue << s['member']['shape']
        when 'map' then queue << s['value']['shape']
        end
      end
      seen.sort
    end

    # ---- serializers ----------------------------------------------------

    def serializers_file
      inputs = operations.filter_map { |_, op| op.dig('input', 'shape') }.uniq
      ops = operations.map { |name, op| serialize_operation(name, op) }.join("\n")
      helpers = reachable_shapes(inputs).map { |name| serialize_shape(name) }.join("\n")
      body = "module Serializers\n#{indent(ops, 2)}\n#{indent(helpers, 2)}end\n"
      header(['json']) + wrap(indent(body, 4))
    end

    def serialize_operation(name, op)
      input = op.dig('input', 'shape')
      value = input ? "serialize_#{Underscore.underscore(input)}(params)" : '{}'
      "def self.#{op_method(name)}(params)\n  JSON.generate(#{value})\nend\n"
    end

    def serialize_shape(name)
      s = shape(name)
      out = +"def self.serialize_#{Underscore.underscore(name)}(values)\n"
      case s['type']
      when 'structure'
        # Json::Builder#structure: the members in the order the caller gave
        # them, nil left out, each under its wire name.
        out << "  data = {}\n  values.each do |key, value|\n    next if value.nil?\n\n    case key\n"
        members(s).each do |m|
          out << "    when :#{m[:ruby]} then data[#{m[:location_name].inspect}] = #{serialize_value(m[:shape_name], 'value')}\n"
        end
        out << "    end\n  end\n  data\n"
      when 'list'
        out << "  values.map { |item| #{serialize_value(s['member']['shape'], 'item')} }\n"
      when 'map'
        out << "  data = {}\n  values.each { |key, item| data[key] = #{serialize_value(s['value']['shape'], 'item')} }\n  data\n"
      end
      out << "end\n"
    end

    def serialize_value(shape_name, var)
      case shape(shape_name)['type']
      when 'structure', 'list', 'map' then "serialize_#{Underscore.underscore(shape_name)}(#{var})"
      when 'timestamp' then "Aws::Runtime::Json.epoch(#{var})"
      when 'blob' then "Aws::Runtime::Json.blob(#{var})"
      else var
      end
    end

    # ---- parsers --------------------------------------------------------

    def parsers_file
      outputs = operations.filter_map { |_, op| op.dig('output', 'shape') }.uniq
      ops = operations.map { |name, op| parse_operation(name, op) }.join("\n")
      helpers = reachable_shapes(outputs).map { |name| parse_shape(name) }.join("\n")
      body = "module Parsers\n#{indent(ops, 2)}\n#{indent(helpers, 2)}end\n"
      header(['json']) + wrap(indent(body, 4))
    end

    # Json::Parser#parse: an empty body is {}.
    def parse_operation(name, op)
      output = op.dig('output', 'shape')
      return "def self.#{op_method(name)}(json)\n  Aws::EmptyStructure.new\nend\n" unless output

      "def self.#{op_method(name)}(json)\n" \
        "  parse_#{Underscore.underscore(output)}(JSON.parse(json.empty? ? '{}' : json))\nend\n"
    end

    # Each value is converted where it is read, so what JSON.parse returns
    # stays in this file and the types hold Strings, Integers and Times.
    def parse_shape(name)
      s = shape(name)
      out = +"def self.parse_#{Underscore.underscore(name)}(value)\n  return nil if value.nil?\n\n"
      case s['type']
      when 'structure'
        ms = members(s)
        values = ms.map { |m| parse_value(m[:shape_name], "value[#{m[:location_name].inspect}]") }
        out << construct(name, values, "Aws::Runtime::Json.union_unknown(value, #{ms.map { |m| m[:location_name] }.inspect})")
      when 'list'
        out << "  value.map { |item| #{parse_value(s['member']['shape'], 'item')} }\n"
      when 'map'
        out << "  data = {}\n  value.each { |key, item| data[key.to_s] = #{parse_value(s['value']['shape'], 'item')} }\n  data\n"
      end
      out << "end\n"
    end

    def parse_value(shape_name, expr)
      case shape(shape_name)['type']
      when 'structure', 'list', 'map' then "parse_#{Underscore.underscore(shape_name)}(#{expr})"
      when 'integer', 'long' then "Aws::Runtime::Json.integer(#{expr})"
      when 'boolean' then "Aws::Runtime::Json.boolean(#{expr})"
      when 'timestamp' then "Aws::Runtime::Json.timestamp(#{expr})"
      when 'blob' then "Aws::Runtime::Json.unblob(#{expr})"
      when 'float', 'double' then "Aws::Runtime::Json.float(#{expr})"
      else "Aws::Runtime::Json.string(#{expr})"
      end
    end
  end
end
