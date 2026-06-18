require 'jsduck/js/rkelly_adapter'
require 'jsduck/js/acorn_adapter'
require 'jsduck/js/associator'
require 'rkelly'

module JsDuck
  module Js

    # A JavaScript parser implementation that uses RKelly and adapts
    # its output to be the same as the old Esprima parser used to
    # produce.
    #
    # When the environment variable JSDUCK_PARSER is set to "acorn",
    # the modern acorn-based front-end is used instead of RKelly. Both
    # produce the same Esprima-compatible AST, so all downstream ExtJS
    # analysis is unaffected.
    class Parser
      ADAPTER = Js::RKellyAdapter.new
      ACORN_ADAPTER = Js::AcornAdapter.new

      def initialize(input, options={})
        @input = input
      end

      # Parses JavaScript source code, turns it into Esprima AST, and
      # associates comments with syntax nodes.
      def parse
        if use_acorn?
          ast = ACORN_ADAPTER.adapt(@input)
        else
          ast = parse_with_rkelly
        end
        return Js::Associator.new(@input).associate(ast)
      end

      # Parses JavaScript source code with RKelly and turns RKelly AST
      # into Esprima AST.
      def parse_with_rkelly
        parser = RKelly::Parser.new
        ast = parser.parse(@input)
        unless ast
          raise syntax_error(parser)
        end

        ast = ADAPTER.adapt(ast)
        # Adjust Program node range
        ast["range"] = [0, @input.length-1]
        ast
      end

      def use_acorn?
        ENV["JSDUCK_PARSER"] == "acorn"
      end

      def syntax_error(parser)
        token = parser.stopped_at
        if token
          "Invalid JavaScript syntax: Unexpected '#{token.value}' on line #{token.range.from.line}"
        else
          "Invalid JavaScript syntax: Unexpected end of file"
        end
      end
    end

  end
end
