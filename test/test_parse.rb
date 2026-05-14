#!/usr/bin/env ruby
require_relative "../lib/spnl_router"

def assert(cond, msg)
  unless cond
    warn "FAIL: #{msg}"; exit 1
  end
end

# --- static routes only ---
src = <<~RB
  class FooController
    ROUTES = {
      "/"      => :index,
      "/about" => :about
    }
    def index; end
    def about; end
  end
RB

name, routes = SpnlRouter.parse(src)
assert name == "FooController",      "class name"
assert routes.length == 2,            "two routes"
assert routes[0].path == "/",         "first path"
assert routes[0].action == :index,    "first action"
assert routes[0].param_name.nil?,     "no param"

# --- param route ---
src = <<~RB
  class B
    ROUTES = { "/posts/:id" => :show }
    def show(id); end
  end
RB

name, routes = SpnlRouter.parse(src)
assert routes[0].path == "/posts/",    "stripped path"
assert routes[0].param_name == "id",   "param name"
assert routes[0].param_offset == 7,    "param offset"

# --- generate output structure ---
out = SpnlRouter.generate(src)
assert out.include?("module Router"),          "module wrapper"
assert out.include?("c = B.new"),              "controller instantiation"
assert out.include?("path.start_with?(\"/posts/\")"), "param branch"
assert out.include?("c.show(id)"),             "action call with param"

# --- multi-mix ---
src = <<~RB
  class C
    ROUTES = {
      "/"          => :home,
      "/api"       => :api,
      "/users/:id" => :user_show,
      "/posts/:id" => :post_show
    }
  end
RB
name, routes = SpnlRouter.parse(src)
assert routes.length == 4, "four routes"
out = SpnlRouter.generate(src)
assert out.include?("when \"/api\""),                "static path"
assert out.scan(/path\.start_with\?/).length == 2,   "two param branches"

puts "all tests passed"
