# %w[rubygems sinatra haml data_mapper].each{ |gem| require gem }
require 'rubygems'
require 'sinatra'
require 'data_mapper'
require 'haml'
require 'mini_magick'

set :username,''
set :token_normal,'shakenN0tstirr3d'
set :token_hight, 'shakenN0tstirr44'
#set :password,'007'
set :id,''

DataMapper.setup(:default, ENV['DATABASE_URL'] || "sqlite3://#{Dir.pwd}/demo.db")
# Class ORM
class Notice
	include DataMapper::Resource

	property :id,          Serial
	property :title,       Text
	property :description, Text
	property :created_at,  String
	property :img,         String
	
	belongs_to :user 
	
	def link
    	"<a href=\"/notice/view/#{self.id}\" class='more'>Leer Mas</a>"
  	end
end
class Document
	include DataMapper::Resource

	property :id, Serial
	property :title, String
	property :description, String
	property :doc, String
	property :created_at, String

	belongs_to :user 
end
class User
	include DataMapper::Resource

	property :id, Serial
	property :name, String, :unique => true
	property :password, String
	property :description, String
	property :role, String

	has n, :documents
	has n, :notices
end
DataMapper.finalize
DataMapper.auto_upgrade!
# Helpers
helpers do
	# ---| Helpers
	def admin? ; request.cookies[settings.username] == settings.token_normal ; end
	def root? ; request.cookies[settings.username] == settings.token_hight ; end
	def protected! ; halt [ 401, 'Not Authorized' ] unless admin? ; end
	def private! ; halt [ 401, 'Not Authorized' ] unless root? ; end

	def logout()
		user = User.get(settings.id)
		"<a href='/logout'>#{user.name}, #{user.description}</a>"
	end
	def add_attributes(opts={})
		attributes = ""
		opts.each do |key,value|
			attributes << key.to_s << "=\"" << value << "\" "
		end
		return attributes
	end
	def get_notices(name_class, per_page, page)
		if page.to_i == 0
			page = 1
		end
		offset = (page.to_i - 1) * 3
		@pagination = name_class.all(:limit => per_page,:offset => offset, :order => :id.desc)
		g_number = name_class.all.size
		
		# get link's number
		num_pages = g_number / per_page
		rest = g_number % per_page
		unless rest == 0
			num_pages = num_pages + 1
		end

		i = 1
		links =""

		while i <= num_pages
			links = links +  "<a href=\"#{i}\">#{i}</a> "
			i = i + 1
		end

		return links
	end
	def sript_html(str)
		all_str = str.gsub(/<\/?[^>]*>/, "")
		split_str = all_str[0,200]

		return split_str
	end
	def resize(path)
		image = MiniMagick::Image.new(path)
		#image = MiniMagick::Image.open(path)
		w, h = image['%w %h'].split
		w = w.to_f
		h = h.to_f
		@@max_size = 528
		if (w > @@max_size || h > @@max_size)
			if (w > h)
				h = (h*(@@max_size/w)).to_i
				w = @@max_size
			else
				w = (w*(@@max_size/h)).to_i
				h = @@max_size
			end
		end

		image.thumbnail "#{w}x#{h}"
		#image.resize "#{w}x#{h}"
		#image.write("image_001.jpg")
	end
	# ---| partials
	def html_helper(template,locals=nil)
		locals = locals.is_a?(Hash) ? locals : {template.to_sym => locals}	
		if template.is_a?(String) || template.is_a?(Symbol)
			template=('helpers/_'+ template.to_s).to_sym
		end
		haml(template,{:layout => false},locals)
	end
end
# ----| Index
get '/' do
	@path = 'Inicio'
	@mini_nav = get_notices(Notice, 2 ,1)
	haml :index
end

# ----| Admin
get '/login' do
	if User.count == 0
		redirect '/new/admin'
	else
		haml :'admin/login'
	end
end

get '/new/admin' do
	haml :'admin/new_admin'
end

post '/new/admin' do

	@user = User.new( :name => params['name'], :password => params['password'])

	@user.attributes = {:role => 'admin'}

	if @user.save
		redirect "/login"
	else
		redirect '/new/admin'
	end
end

get '/root' do
	private!
	"Hello Big Boss..!!"
end

get '/admin' do
	protected!
	redirect '/admin/notice'
end

get %r{/admin/([\w]+)} do |element|
	protected!
	user = User.get(settings.id);
	if element == 'notice'
		@elements = user.notices.all()
		@name = 'notice'
		@title = 'Lista de Noticias'
	elsif element == 'document'
		@elements = user.documents.all()
		@name = 'document'
		@title = 'Lista de Documentos'
	end
	haml :'admin/index', :layout => :'layout/admin' 
end
post '/login' do
	user = User.all(:name => params['username'], :password => params['password'])

	unless user.empty?
		settings.username = user[0].name
		#settings.password = user[0].password
		settings.id = user[0].id # set :id
		
		unless user[0].role == 'admin'
			response.set_cookie(settings.username, settings.token_hight)
			redirect '/root'
		else
			response.set_cookie(settings.username, settings.token_normal)
			redirect '/admin'
		end
	else
		"Username or Password incorrect"
	end
end
get('/logout'){ response.set_cookie(settings.username, false) ; redirect '/' }
# ----| Notices
# notice 1..9
get %r{/notice/([\d]+)} do |num|
	@path = 'Inicio / Noticias: Pagina ' + num
	@mini_nav = get_notices Notice, 3 ,num
	@most_recent_notice = Notice.all(:fields =>[:id, :title,:created_at],:limit => 5, :order => :id.desc);
	haml :'notices/index' # ,:locals => {:path => ": Inicio / "}
end
# view noticev
get '/notice/view/:id' do
	@path = 'Inicio / Noticia / View / ' + params[:id]
	@notice = Notice.get(params[:id])
	haml :'notices/notice'
end
#  create notice
get '/notice/new' do
	protected!
	haml :'notices/create', :layout => :'layout/admin'
end
post '/notice/create' do

	user = User.get(settings.id)
	notice = Notice.create :user => user
	
	path_img = ""

	unless params[:file] &&	(tmpfile = params[:file][:tempfile]) &&	(name = params[:file][:filename])
		@error = "No file selected"
		return haml(:upload)
	else
		directory = "./public/uploads/"
		rename = "#{notice.id}" + File.extname(name)
		path = File.join(directory, rename)
		File.open(path, "wb") do |f|
			f.write(tmpfile.read)
			#f.rename(name,"#{notice.id}.jpg")
		end
		resize(path)
		path_img = "/uploads/" + rename
	end

	notice.attributes = {:title => params[:title], :description => params[:description], :created_at => Time.now, :img => path_img }
	
	if notice.save
		status 201
		redirect '/admin/notice'  
	else
		status 412
		"redirect error"
	end
end
# update notice
get '/notice/edit/:id' do
	protected!
	user = User.get(settings.id)
	@notice = user.notices.get(params[:id])
	haml :'notices/edit', :layout => :'layout/admin'
end
put '/notice/:id' do
	user = User.get(settings.id)
	notice = user.notices.get(params[:id])
	
	path_img = ""

	unless params[:file] &&	(tmpfile = params[:file][:tempfile]) &&	(name = params[:file][:filename])
		path_img = notice.img
	else
		directory = "./public/uploads/"
		rename = "#{notice.id}" + File.extname(name)
		path = File.join(directory, rename)
		File.open(path, "wb") { |f| f.write(tmpfile.read) }
		resize(path)
		path_img = "/uploads/" + rename
	end

	notice.attributes ={
		:title => params[:title], 
		:description => params[:description], 
		:created_at => Time.now, 
		:img => path_img
	}

	if notice.save
		status 201
		redirect '/admin'  
	else
		status 412
		"error"   
	end
end
# delete notice
get '/notice/delete/:id' do
	protected!
  	user = User.get(settings.id)
  	@notice = user.notices.get(params[:id])
  	haml :'notices/delete', :layout => false
end
delete '/notice/:id' do
  user = User.get(settings.id)
  user.notices.get(params[:id]).destroy
  redirect '/admin' 
end
# ----| Profile
get '/profile' do
	@path = 'Inicio / Presentacion '
	haml :'profile/index'
end
get '/profile/time' do
	"The time is " + Time.now.to_s 
end
get %r{/profile/([\d]+)} do |num|
	url = ('profile/profile' + num.to_s).to_sym
	haml(url,{:layout => false})
end
# ----| Document
# notice 1..9
get %r{/document/([\d]+)} do |num|
	@path = 'Inicio / Noticias: Pagina ' + num
	@mini_nav = get_notices(Notice, 3 ,num)
	@most_recent_notice = Notice.all(:fields =>[:id, :title,:created_at],:limit => 5, :order => :id.desc);
	haml :'notices/index' # ,:locals => {:path => ": Inicio / "}
end
# iew noticev
get '/document/view/:id' do
	#@path = 'Inicio / Noticia / View / ' + params[:id]
	@document = Document.get(params[:id])
	haml :'notices/notice'
end
#  add document
get '/document/new' do
	protected!
	haml :'document/create', :layout => :'layout/admin'
end
post '/document/create' do

	user = User.get(settings.id)
	document = Document.create :user => user
	
	path_doc = ''
	
	unless params[:file] &&	(tmpfile = params[:file][:tempfile]) &&	(name = params[:file][:filename])
		@error = "No file selected"
		url = ('/document/new').to_sym
		return haml(url)
	else
		directory = "./public/docs/"
		rename = "#{document.id}" + File.extname(name)

		path = File.join(directory, rename)
		File.open(path, "wb") { |f| f.write(tmpfile.read) }
		path_doc =  "/docs/" + rename
	end
	
	document.attributes = {:title => params[:title], :description => params[:description], :created_at => Time.now, :doc => path_doc }
	
	if document.save
		status 201
		redirect '/admin/document'  
	else
		status 412
		"redirect error"
	end
end
# update notice
get '/document/edit/:id' do
	protected!
	user = user.get(settings.id)
	@document = user.documents.get(params[:id])
	haml :'document/edit', :layout => :'layout/admin'
end
put '/document/:id' do
	user = user.get(settings.id)
	document = user.documents.get(params[:id])
	
	path_doc = ""

	unless params[:file] &&	(tmpfile = params[:file][:tempfile]) &&	(name = params[:file][:filename])
		path_doc = document.doc
	else
		directory = "./public/docs/"
		rename = "#{document.id}" + File.extname(name)
		path = File.join(directory, rename)
		File.open(path, "wb") { |f| f.write(tmpfile.read) }
		path_doc =  "/docs/" + rename
	end

	document.attributes ={
		:title => params[:title], 
		:description => params[:description], 
		:created_at => Time.now, 
		:doc => path_doc
	}

	if document.save
		status 201
		redirect '/admin/document'  
	else
		status 412
		"error"
	end
end
# delete notice
get '/document/delete/:id' do
  protected!
  user = user.get(settings.id)
  @document = user.documents.get(params[:id])
  haml :'document/delete', :layout => false
end
delete '/document/:id' do
  user = user.get(settings.id)
  user.documents.get(params[:id]).destroy
  redirect '/admin/document' 
end
# ----| Stylesheet
get '/stylesheets/style.css' do
  header 'Content-Type' => 'text/css; charset=utf-8'
  sass :'stylesheets/style'
end
get '/stylesheets/nice-principal.css' do
  header 'Content-Type' => 'text/css; charset=utf-8'
  sass :'stylesheets/nice-principal'
end

