require 'jsduck/js/acorn_adapter'
require 'jsduck/js/associator'

module JsDuck
  module Js

    # JavaScript parser front-end based on acorn.
    #
    # Parses modern JavaScript into an Esprima-compatible AST (via
    # AcornAdapter) and associates doc-comments with the syntax nodes,
    # so all downstream Ext JS analysis works unchanged. This replaces
    # the original RKelly (ECMAScript 5.1 only) front-end.
    class Parser
      ACORN_ADAPTER = Js::AcornAdapter.new

      def initialize(input, options={})
        @input = input
      end

      # Parses JavaScript source code into an Esprima-compatible AST and
      # associates comments with syntax nodes.
      def parse
        ast = ACORN_ADAPTER.adapt(@input)
        return Js::Associator.new(@input).associate(ast)
      end
    end

  end
end
