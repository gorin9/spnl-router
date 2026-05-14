class BlogController
  ROUTES = {
    "/"          => :index,
    "/about"     => :about,
    "/posts/:id" => :show
  }

  def index
    @posts = Post.all
    @page_title = "Latest posts"
    render_posts_index
  end

  def show(id)
    @post = Post.all[id]
    @page_title = @post.title
    render_posts_show
  end

  def about
    @page_title = "About"
    render_about
  end

  # framework helper (Router から呼ばれる)
  def set_chrome(nav, content)
    @active_nav = nav
    @content    = content
    @site_name  = "spinel.blog"
  end
end
