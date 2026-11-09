module SpnlRouter
  class RuntimeRoute
    attr_reader :verb, :pattern, :handler
    def initialize(verb,pattern,handler)
      @verb=verb;@pattern=pattern;@handler=handler
    end
  end
  class Runtime
    def initialize
      @routes=[]
    end
    def add(verb,pattern,handler)
      @routes.push(RuntimeRoute.new(verb,pattern,handler))
      self
    end
    def match(pattern,path)
      expected=pattern.split('/',-1);actual=path.split('/',-1)
      return nil unless expected.length==actual.length
      params={}
      expected.each_with_index do |part,i|
        if part.start_with?(':')
          return nil if actual[i].empty?
          params[part[1,part.length]]=actual[i]
        elsif part!=actual[i]
          return nil
        end
      end
      params
    end
    def dispatch_result(verb,request_path)
      path=request_path.split('?',2)[0]
      allowed=[]
      @routes.each do |route|
        params=match(route.pattern,path)
        next if params.nil?
        allowed.push(route.verb)
        if verb==route.verb || (verb=='HEAD' && route.verb=='GET')
          return [200,route.handler.call(params),'']
        end
      end
      return [405,'Method Not Allowed',(allowed+(allowed.include?('GET') ? ['HEAD'] : [])).uniq.join(', ')] unless allowed.empty?
      [404,'404','']
    end
  end
end
