require 'tmpdir'
require 'open3'
require_relative '../lib/spnl_router'
source=<<~RB
  class Controller
    ROUTES = {'/' => :home, '/users/:id' => :user, '/posts/:id' => :post}
    def home; ''; end
    def user(id); 'user:'+id.to_s; end
    def post(id); 'post:'+id.to_s; end
  end
RB
Dir.mktmpdir do |dir|
 file=dir+'/router.rb'
 File.write(file,source+SpnlRouter.generate(source,target_module:'Routes',layout:false)+"['/','/users/2','/posts/3','/posts/no','/posts/1/extra'].each { |p| puts Routes.dispatch(p) }\n")
 expected,status=Open3.capture2('ruby',file);raise 'CRuby failed' unless status.success?
 raise 'compile failed' unless system(ENV.fetch('SPINEL','spinel'),file,'-o',dir+'/router')
 actual,status=Open3.capture2(dir+'/router');raise 'router AOT parity failed' unless status.success? && actual==expected
 puts 'Generated router compiles and matches CRuby'
end
