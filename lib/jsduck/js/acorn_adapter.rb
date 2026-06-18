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
        # max_nesting: false -- acorn ASTs can nest far deeper than
        # Ruby's default JSON nesting limit of 100.
        data = JSON.parse(run_bridge(input), :max_nesting => false)
        ast = normalize(data["program"])
        ast["comments"] = data["comments"] || []
        ast
      end

      private

      def run_bridge(input)
        out, err, status = Open3.capture3(node_env, NODE_BIN, BRIDGE, :stdin_data => input)
        unless status.success?
          raise "Invalid JavaScript syntax: #{err.strip}"
        end
        out
      end

      # Environment for the Node child process. JSDUCK_NODE_PATH lets the
      # bridge locate acorn (prepended to NODE_PATH) WITHOUT polluting the
      # global environment of other tools (e.g. Babel) in the same build.
      def node_env
        env = {}
        extra = ENV["JSDUCK_NODE_PATH"]
        if extra && !extra.empty?
          existing = ENV["NODE_PATH"]
          env["NODE_PATH"] = existing && !existing.empty? ?
            extra + File::PATH_SEPARATOR + existing : extra
        end
        env
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
            normalize_params(node) if node["params"].is_a?(Array)
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

      # Unwraps modern function parameter syntax to the plain identifier
      # JSDuck's param model expects -- mirroring what Babel used to do in
      # the build pipeline, but at the AST level:
      #   foo(a = 1)   AssignmentPattern -> Identifier "a"
      #   foo(...rest) RestElement       -> Identifier "rest"
      # Destructuring patterns are left as-is (they have no single name).
      def normalize_params(node)
        node["params"] = node["params"].map {|p| unwrap_param(p) }
      end

      def unwrap_param(p)
        return p unless p.is_a?(Hash)
        case p["type"]
        when "AssignmentPattern" then p["left"] || p
        when "RestElement"       then p["argument"] || p
        else p
        end
      end

    end

  end
end
