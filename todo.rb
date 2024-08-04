require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

# this sets up Sinatra to use sessions
# if a value is not provided for `:session_secret`, Sinatra will generate a random
# session_secret everytime it starts. I.e., a different secret everytime the application
# is stopped and started again. Since the secret is used to verify the data stored 
# in that session, if that secret value changes, then any session that exists will 
# become invalid immediately. By providing a secret value, we make sure that any
# sessions that are created will continue to work no matter how many times we 
# restart Sinatra.
configure do
  enable :sessions
  set(:session_secret, SecureRandom.hex(32))
  set(:erb, :escape_html => true)
end

helpers do
  def todos_remaining_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end

  def list_complete?(list)
    todos_count(list) > 0 && todos_remaining_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list) }
    
    incomplete_lists.each { |list| yield(list, lists.index(list)) }
    complete_lists.each { |list| yield(list, lists.index(list)) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }
    
    incomplete_todos.each { |todo| yield(todo, todos.index(todo)) }
    complete_todos.each { |todo| yield(todo, todos.index(todo)) }
  end
end

before do
  session[:lists] ||= [] # if session[:lists] is falsey, set return value to `[]`
end

get "/" do
  redirect "/lists"
end

# view all the lists
get "/lists" do
  @lists = session[:lists]
  erb(:lists, layout: :layout)
end

### old version of the above route
# get "/lists/new" do
#   session[:lists] << { name: "new lists", todos: [] }
#   redirect "/lists"
# end

# render the new list form
get "/lists/new" do
  erb(:new_list, layout: :layout)
end

# returns an error msg if name is invalid, otherwise returns nil
def error_for_list_name(name)
  if !(1..100).cover?(name.size)
    "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    "List name must be unique."
  end
end

# returns an error msg if name is invalid, otherwise returns nil
def error_for_todo(name)
  if !(1..100).cover?(name.size)
    "The todo name must be between 1 and 100 characters."
  end
end

##############
def next_list_id(session)
  # session[:lists] = {}
  # session[:lists] = {{id: 0, name: name0, ...}, {id: 1, name: name1, ...}, {id: 2, name: name2, ...}} ...
  max = session.map { |list| list[:id] }.max || 0
  max + 1
end

# create a new list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb(:new_list, layout: :layout)
  else
    id = next_list_id(session[:lists])
    session[:lists] << { id: id, name: list_name, todos: [] } # session[:lists] << { name: list_name, todos: [] }
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# def load_list(index)
#   list = session[:lists][index] if index && session[:lists][index]
#   return list if list

#   session[:error] = "The specified list was not found."
#   redirect "/lists"
# end

def load_list(id)
  list = session[:lists].find { |list| list[:id] == id } 
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# render a list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id)
  erb(:list, layout: :layout)
end

# edit an existing list
get "/lists/:id/edit" do
  id = params[:id].to_i
  @list = load_list(id) #@list = session[:lists][id]
  erb(:edit_list, layout: :layout)
end

# update an existing list
post "/lists/:id" do
  list_name = params[:list_name].strip
  id = params[:id].to_i
  @list = load_list(id) #@list = session[:lists][id]

  error = error_for_list_name(list_name)

  if error
    session[:error] = error
    erb(:edit_list, layout: :layout)
  else
    @list[:name] = list_name
    session[:success] = "The list has been updated."
    redirect "/lists/#{id}"
  end
end

# delete a list
post "/lists/:id/destroy" do
  id = params[:id].to_i
  session[:lists].reject! { |list| list[:id] == id } # session[:lists].delete_at(id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = "The list has been deleted."
    redirect "/lists"
  end
end

def next_todo_id(todos)
  max = todos.map { |todo| todo[:id] }.max || 0
  max + 1
end

# add a todo item to a list
post "/lists/:list_id/todos" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) # @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb(:list, layout: :layout)
  else
    id = next_todo_id(@list[:todos])
    @list[:todos] << { id: id, name: text, completed: false }
    session[:success] = "The todo is successfully added."
    redirect "/lists/#{@list_id}"
  end
end

# delete a todo item
post "/lists/:list_id/todos/:id/destroy" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:id].to_i
  #@list[:todos].delete_at todo_id
  @list[:todos].reject! { |todo| todo[:id] == todo_id }

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# update todo status
post "/lists/:list_id/todos/:id" do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id) # @list = session[:lists][@list_id]
  todo_id = params[:id].to_i

  is_completed = params[:completed] == "true"
  #@list[:todos][todo_id][:completed] = is_completed
  selected_todo = @list[:todos].find { |todo| todo[:id] == todo_id } # hash returned
  selected_todo[:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# mark all todos as complete for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = load_list(@list_id) # @list = session[:lists][@list_id]
  
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end