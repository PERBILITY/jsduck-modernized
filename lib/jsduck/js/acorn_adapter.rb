require 'json'
require 'open3'

module JsDuck
  module Js

    # Parses JavaScript using acorn (a modern, maintained ESTree parser)
    # by shelling out to a small Node.js bridge, then adapts acorn's
    # output into the Esprima-compatible AST that the rest of JSDuck
    # already consumes.
    #
    # This is a drop-in replacement for the RKelly front-end: the entire
    # downstream ExtJS analysis (Js::Class, Js::Method, Js::Property,
    # Js::Event, Associator, Merger, ...) keeps operating on the same
    # node hashes -- only the parser that produces them changes.
    #
    # The only structural differences between acorn output and what
    # JSDuck expects are handled here:
    #
    #  * acorn stores positions as `start`/`end` integer offsets plus a
    #    `loc` object; JSDuck expects a single `range` array of the form
    #    [start, end, line].  We build that and drop the acorn-specific
    #    keys (otherwise Js::Node#body would mistake them for child nodes).
    class AcornAdapter
      BRIDGE  = File.expand_path("acorn_bridge.js", File.dirname(__FILE__))
      NODE_BIN = ENV["JSDUCK_NODE"] || "node"

      # Parses the given source and returns the Program node (Esprima
      # format) with an attached "comments" array.
      def adapt(input)
        data = JSON.parse(run_bridge(input))
        ast = normalize(data["program"])
        ast["comments"] = data["comments"] || []
        ast
      end

      private

      def run_bridge(input)
        out, err, status = Open3.capture3(NODE_BIN, BRIDGE, :stdin_data => input)
        unless status.success?
          raise "Invalid JavaScript syntax: #{err.strip}"
        end
        out
      end

      # Recursively rewrites acorn nodes in place:
      #  * turns start/end/loc into a 3-element range [start, end, line]
      #  * removes the acorn-specific start/end/loc keys
      def normalize(node)
        case node
        when Hash
          if node.key?("type")
            s   = node.delete("start")
            e   = node.delete("end")
            loc = node.delete("loc")
            line = (loc && loc["start"]) ? loc["start"]["line"] : nil
            node.keys.each {|k| node[k] = normalize(node[k]) }
            node["range"] = [s, e, line]
          else
            node.keys.each {|k| node[k] = normalize(node[k]) }
          end
          node
        when Array
          node.map {|v| normalize(v) }
        else
          node
        end
      end

    end

  end
end
