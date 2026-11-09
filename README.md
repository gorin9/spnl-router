# spnl-router

Validate a controller's literal route table and generate direct HTTP dispatch calls.
This remains a static-generation option; modern Spinel also supports finite dynamic
send/Proc dispatch, so external generation is no longer a language requirement.
Static output keeps call targets inspectable and inference predictable.

A tested runtime alternative is also available as a spin package:

```ruby
require "spnl_router"
routes = SpnlRouter::Runtime.new
routes.add("GET", "/users/:id", proc { |params| "user:" + params["id"] })
result = routes.dispatch_result("GET", "/users/42")
```

Runtime parameters remain Strings and handlers share a Hash-to-String contract.
Static generated id routes additionally validate/cast numeric ids. The two modes
therefore have explicitly different parameter contracts; choose one for your app.
The demo retains static generation for inspectable calls and numeric constraints.

```ruby
class Controller
  ROUTES = {
    "/" => :home,
    "/users/:id" => {action: :show, nav: "users"},
    "POST /users" => :create
  }
end
```

```sh
ruby bin/spnl-router controller.rb --module-name Routes -o routes.generated.rb
```

Parsing uses Ripper, never application eval. Exactly one literal class/module ROUTES
Hash is required. Namespaced classes and nested literal action metadata work. Interpolation
and executable route values are rejected. Route declarations are trusted build inputs.

`dispatch_result(method,path)` returns status, body and (for 405) allowed-method text.
`dispatch(path)` preserves the historical GET/body API. GET also handles HEAD; callers
omit the body on the wire. Query strings are removed before matching. Segments match
exactly; :id and *_id must be unsigned decimal integers, other parameters are strings.
The default layout integration still calls set_chrome/render_layout; library users may
call SpnlRouter.generate(source, layout: false) for plain action bodies.
Routes are matched in declaration order. URL percent-decoding is the application's policy;
this generator does not decode encoded slashes or turn a failed id parse into zero.

## Compatibility and verification

Supported baseline: Spinel `2026.10.25` (Linux) and CRuby 3.1+. CI also checks the
reference master commit `60c0273261415d2b5edd6480667a705a68addbd2`; this is a pinned
comparison, not an assertion about every future master build. Check CHANGELOG before upgrading.
No performance or binary-size claim is inherited from the May prototype.

Run `rake test`. Runtime packages additionally use `spin test`; generator repositories
use `ruby scripts/verify_runtime.rb` to compile their generated code and compare with CRuby.
See CONTRIBUTING.md. Original notes are in `docs/historical-readme-may-2026.md`.

MIT licensed. Development version; no gem or package-index release is published automatically.
