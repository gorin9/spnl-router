require_relative '../lib/spnl_router'
def assert(x,m); raise m unless x; end
class SampleController
  ROUTES = {'/' => :home, '/users/:id' => :user, '/posts/:id' => :post, 'POST /users' => :create}
  def set_chrome(nav,body); @body=body; end
  def render_layout; @body; end
  def home; ''; end
  def user(id); "user:#{id}"; end
  def post(id); "post:#{id}"; end
  def create; 'created'; end
end
src = File.read(__FILE__)
name, routes=SpnlRouter.parse(src)
assert(name=='SampleController' && routes.length==4, 'AST parse')
eval(SpnlRouter.generate(src, target_module:'Generated'))
assert(Generated.dispatch_result('GET','/')[0]==200,'empty body')
assert(Generated.dispatch('/users/42?x=1')=='user:42','query')
assert(Generated.dispatch('/posts/3')=='post:3','multiple param routes')
assert(Generated.dispatch_result('GET','/posts/abc')[0]==404,'numeric id')
assert(Generated.dispatch_result('GET','/posts/1/extra')[0]==404,'segment boundary')
assert(Generated.dispatch_result('DELETE','/users')[0]==405,'405')
assert(Generated.dispatch_result('POST','/users')[1]=='created','POST')
assert(Generated.dispatch_result('HEAD','/users/42')[0]==200,'HEAD')
only='class Only; ROUTES = {"/posts/:id" => :post}; end'
RubyVM::InstructionSequence.compile(SpnlRouter.generate(only))
begin
  SpnlRouter.parse('class Evil; ROUTES = system("false"); end'); raise 'accepted code'
rescue ArgumentError
end
puts 'route AST, generated execution, methods, boundaries and empty response passed'
