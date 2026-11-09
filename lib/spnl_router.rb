# frozen_string_literal: true
require "ripper"

module SpnlRouter
  VERSION = "0.2.0"
  Route = Struct.new(:path, :action, :nav, :param_name, :param_offset, :http_method)

  # Parse literal ROUTES without executing any application code.
  def self.literal(node)
    raise ArgumentError, "route values must be literals" unless node.is_a?(Array)
    case node[0]
    when :string_literal
      content = node[1]
      raise ArgumentError, "interpolated routes are unsupported" unless content && content[0] == :string_content && content.drop(1).all? { |x| x[0] == :@tstring_content }
      content.drop(1).map { |x| x[1] }.join
    when :symbol_literal
      token = node.dig(1, 1)
      raise ArgumentError, "invalid symbol" unless token && [:@ident, :@op, :@const].include?(token[0])
      token[1].to_sym
    when :hash
      list = node[1] ? node[1][1] : []
      seen = {}
      list.to_h do |assoc|
        raise ArgumentError, "literal route pairs required" unless assoc[0] == :assoc_new
        key = assoc[1][0] == :@label ? assoc[1][1].delete_suffix(':').to_sym : literal(assoc[1])
        raise ArgumentError, "duplicate route key" if seen[key]
        seen[key] = true
        [key, literal(assoc[2])]
      end
    else
      raise ArgumentError, "unsupported route expression: #{node[0]}"
    end
  end

  def self.const_name(node)
    case node[0]
    when :const_ref, :var_ref then node[1][1]
    when :const_path_ref then const_name(node[1]) + '::' + node[2][1]
    else raise ArgumentError, "unsupported class name"
    end
  end

  def self.walk(node, scope = [], found = [])
    return found unless node.is_a?(Array)
    if [:class, :module].include?(node[0])
      name = const_name(node[1])
      return walk(node[node[0] == :class ? 3 : 2], scope + [name], found)
    end
    if node[0] == :assign && node.dig(1, 0) == :var_field && node.dig(1, 1, 0) == :@const && node.dig(1, 1, 1) == 'ROUTES'
      found << [scope.join('::'), literal(node[2])]
    end
    node.each { |child| walk(child, scope, found) if child.is_a?(Array) }
    found
  end

  def self.parse(source)
    ast = Ripper.sexp(source)
    raise ArgumentError, "invalid Ruby source" unless ast
    found = walk(ast)
    raise ArgumentError, "expected exactly one class ROUTES hash" unless found.length == 1 && !found[0][0].empty?
    name, table = found.first
    raise ArgumentError, "ROUTES must be a nonempty Hash" unless table.is_a?(Hash) && !table.empty?
    seen = {}
    routes = table.map do |key, value|
      raise ArgumentError, "route key must be a String" unless key.is_a?(String)
      verb, path = key.include?(' ') ? key.split(' ', 2) : ['GET', key]
      raise ArgumentError, "invalid HTTP method" unless %w[GET POST PUT PATCH DELETE HEAD OPTIONS].include?(verb)
      raise ArgumentError, "invalid path" unless path.start_with?('/') && !path.match?(/[?#\r\n]/)
      metadata = value.is_a?(Hash) ? value : {action: value}
      action = metadata[:action]
      raise ArgumentError, "invalid action" unless action.to_s.match?(/\A[a-z_]\w*[!?]?\z/)
      params = path.split('/').select { |s| s.start_with?(':') }.map { |s| s.delete_prefix(':') }
      raise ArgumentError, "invalid or duplicate path parameter" unless params.uniq == params && params.all? { |n| n.match?(/\A[a-z_]\w*\z/) }
      raise ArgumentError, "duplicate route" if seen[[verb, path]]
      seen[[verb, path]] = true
      r = Route.new(path, action.to_sym, metadata[:nav], nil, nil, verb)
      if params.length == 1
        r.param_name = params.first
        r.param_offset = path.index(':')
      end
      r
    end
    [name, routes]
  end

  def self.generate(source, target_module: "Router", layout: true)
    raise ArgumentError, "invalid module name" unless target_module.match?(/\A[A-Z]\w*(?:::[A-Z]\w*)*\z/)
    controller, routes = parse(source)
    branches = routes.map do |r|
      parts = r.path.split('/', -1)
      params = []
      regex = parts.map do |segment|
        if segment.start_with?(':')
          params << segment.delete_prefix(':')
          '([^/]+)'
        else
          Regexp.escape(segment)
        end
      end.join('/')
      # Keep exact paths and generated direct calls for predictable AOT inference.
      matcher = params.empty? ? "path == #{r.path.inspect}" : "(match = /\\A#{regex.gsub('/', '\\/')}\\z/.match(path))"
      args = params.each_with_index.map { |n, i| n == 'id' || n.end_with?('_id') ? "match[#{i+1}].to_i" : "match[#{i+1}]" }.join(', ')
      validation = params.each_with_index.select { |n, _| n == 'id' || n.end_with?('_id') }.map { |_, i| "return [404, \"404\"] unless match[#{i+1}].match?(/\\A[0-9]+\\z/)" }.join("\n        ")
      output = layout ? "c.set_chrome(#{(r.nav || infer_nav(r.path)).inspect}, body)\n          body = c.render_layout" : ''
      <<~RB
          if #{matcher}
            allowed.push(#{r.http_method.inspect})
            if verb == #{r.http_method.inspect} || (verb == "HEAD" && #{r.http_method.inspect} == "GET")
              #{validation}
              c = #{controller}.new
              #{layout ? 'c.set_chrome("", "")' : ''}
              body = c.#{r.action}(#{args})
              #{output}
              return [200, body, ""]
            end
          end
      RB
    end.join
    output = <<~RB
      # AUTO-GENERATED by spnl-router #{VERSION}; do not edit
      module #{target_module}
        def self.dispatch_result(verb, request_path)
          path = request_path.split("?", 2)[0]
          allowed = []
      #{branches.lines.map { |l| '    ' + l }.join}
          return [405, "Method Not Allowed", (allowed + (allowed.include?("GET") ? ["HEAD"] : [])).uniq.join(", ")] unless allowed.empty?
          [404, "404", ""]
        end
        # Legacy content API. HTTP callers should use dispatch_result.
        def self.dispatch(path)
          result = dispatch_result("GET", path)
          result[1]
        end
      end
    RB
    output.lines.map(&:rstrip).join("\n") + "\n"
  end

  def self.infer_nav(path)
    path == '/' ? 'home' : path.split('/').reject(&:empty?).first.to_s
  end
end
