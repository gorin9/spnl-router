require_relative '../spnl_router'
routes=SpnlRouter::Runtime.new
routes.add('GET','/users/:id',proc { |params| 'user:'+params['id'] })
routes.add('POST','/users',proc { |params| 'created' })
raise 'proc route' unless routes.dispatch_result('GET','/users/42')[1]=='user:42'
raise 'method' unless routes.dispatch_result('DELETE','/users')[0]==405
raise 'boundary' unless routes.dispatch_result('GET','/users/42/extra')[0]==404
puts 'runtime Proc-table routing passed'
