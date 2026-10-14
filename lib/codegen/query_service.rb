# frozen_string_literal: true

require_relative 'service'

module Codegen
  # The "query" protocol (such as STS): a form-encoded body of Action,
  # Version and the input members, and an XML response.
  class QueryService < Service
    def initialize(api_path, module_name:)
      super
      raise "not a query protocol model: #{metadata['protocol']}" unless metadata['protocol'] == 'query'
    end

    private

    def transport(name, op)
      m = op_method(name)
      "xml = stub ? stub_xml(stub, body) : send_query(body, #{signed?(op)})\ndata = Parsers.#{m}(xml)\n"
    end

    # ---- serializers ----------------------------------------------------

    def serializers_file
      inputs = operations.filter_map { |_, op| op.dig('input', 'shape') }.uniq
      reachable = reachable_structures(inputs)
      ops = operations.map { |name, op| serialize_operation(name, op) }.join("\n")
      helpers = reachable.map { |name| serialize_structure(name) }.join("\n")
      body = "module Serializers\n#{indent(ops, 2)}\n#{indent(helpers, 2)}end\n"
      header + wrap(indent(body, 4))
    end

    def serialize_operation(name, op)
      out = +"def self.#{op_method(name)}(params)\n"
      out << "  pairs = [[\"Action\", #{name.inspect}], [\"Version\", #{metadata['apiVersion'].inspect}]]\n"
      if (input = op.dig('input', 'shape'))
        out << "  serialize_#{Underscore.underscore(input)}(pairs, \"\", params)\n"
      end
      out << "  Aws::Runtime::Query.body(pairs)\nend\n"
    end

    def serialize_structure(name)
      out = +"def self.serialize_#{Underscore.underscore(name)}(pairs, prefix, values)\n"
      members(shape(name)).each do |m|
        out << "  value = Aws::Runtime::Query.member(values, :#{m[:ruby]})\n"
        out << "  unless value.nil?\n#{indent(serialize_value(m[:shape_name], m[:location_name], "value", m[:flattened]), 4)}  end\n"
      end
      out << "end\n"
    end

    def serialize_value(shape_name, query_name, var, flattened, depth = 0)
      s = shape(shape_name)
      name = "\"\#{prefix}#{query_name}\""
      case s['type']
      when 'structure'
        "serialize_#{Underscore.underscore(shape_name)}(pairs, \"\#{prefix}#{query_name}.\", #{var})\n"
      when 'list'
        member_ref = s['member']
        item = "item#{depth}"
        index = "index#{depth}"
        item_prefix = if flattened
                        "\"\#{prefix}#{member_ref['locationName'] || query_name}.\#{#{index} + 1}\""
                      else
                        "\"\#{prefix}#{query_name}.#{member_ref['locationName'] || 'member'}.\#{#{index} + 1}\""
                      end
        inner = serialize_list_item(member_ref['shape'], item, item_prefix, depth + 1)
        "if #{var}.empty?\n  pairs << [#{name}, \"\"]\nelse\n  #{var}.each_with_index do |#{item}, #{index}|\n#{indent(inner, 4)}  end\nend\n"
      when 'timestamp'
        "pairs << [#{name}, Aws::Runtime::Query.timestamp(#{var})]\n"
      else
        "pairs << [#{name}, #{var}.to_s]\n"
      end
    end

    def serialize_list_item(shape_name, var, item_prefix, depth)
      s = shape(shape_name)
      case s['type']
      when 'structure'
        "serialize_#{Underscore.underscore(shape_name)}(pairs, #{item_prefix} + \".\", #{var})\n"
      when 'timestamp' then "pairs << [#{item_prefix}, Aws::Runtime::Query.timestamp(#{var})]\n"
      else "pairs << [#{item_prefix}, #{var}.to_s]\n"
      end
    end

    # ---- parsers --------------------------------------------------------

    def parsers_file
      outputs = operations.filter_map { |_, op| op.dig('output', 'shape') }.uniq
      reachable = reachable_structures(outputs)
      ops = operations.map { |name, op| parse_operation(name, op) }.join("\n")
      helpers = reachable.map { |name| parse_structure(name) }.join("\n")
      body = "module Parsers\n#{indent(ops, 2)}\n#{indent(helpers, 2)}end\n"
      header + wrap(indent(body, 4))
    end

    def parse_operation(name, op)
      output = op.dig('output', 'shape')
      return "def self.#{op_method(name)}(xml)\n  Aws::EmptyStructure.new\nend\n" unless output

      wrapper = op.dig('output', 'resultWrapper')
      out = +"def self.#{op_method(name)}(xml)\n"
      out << "  root = Aws::Runtime::Xml.parse(xml)\n"
      out << (wrapper ? "  node = root.child(#{wrapper.inspect})\n" : "  node = root\n")
      out << "  parse_#{Underscore.underscore(output)}(node)\nend\n"
    end

    def parse_structure(name)
      ms = members(shape(name))
      out = +"def self.parse_#{Underscore.underscore(name)}(node)\n"
      out << "  return nil if node.nil?\n\n"
      out << "  Types::#{name}.new(\n"
      out << ms.map { |m| "    #{m[:ruby]}: #{parse_member(m)}" }.join(",\n")
      out << "\n  )\nend\n"
    end

    def parse_member(m)
      element = "node.child(#{m[:location_name].inspect})"
      s = m[:shape]
      case s['type']
      when 'structure' then "parse_#{Underscore.underscore(m[:shape_name])}(#{element})"
      when 'list'
        member_ref = s['member']
        item_name = m[:flattened] ? m[:location_name] : (member_ref['locationName'] || 'member')
        scope = m[:flattened] ? 'node' : element
        conv = scalar_conversion(member_ref['shape'], 'item')
        "Aws::Runtime::Xml.list(#{scope}, #{item_name.inspect}).map { |item| #{conv} }"
      else
        scalar_conversion(m[:shape_name], element)
      end
    end

    def scalar_conversion(shape_name, node_expr)
      s = shape(shape_name)
      case s['type']
      when 'structure' then "parse_#{Underscore.underscore(shape_name)}(#{node_expr})"
      when 'integer', 'long' then "Aws::Runtime::Xml.integer(#{node_expr})"
      when 'boolean' then "Aws::Runtime::Xml.boolean(#{node_expr})"
      when 'timestamp' then "Aws::Runtime::Xml.timestamp(#{node_expr})"
      else "Aws::Runtime::Xml.text(#{node_expr})"
      end
    end
  end
end
