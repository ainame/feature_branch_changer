require 'sinatra/base'
require 'git'

class GitOperator
  def initialize(working_dir)
    @git = Git.open(working_dir)
  end

  def get_current_branch
    @git.branches.select {|branch| branch.current }.first
  end

  def get_other_branches
    @git.branches.select {|branch| !branch.current }
  end

  def fetch_remotes
    @git.fetch
  end

  def branch_delete branch
    @git.branch_delete branch
  end

  def checkout_remote_branch_head branch
    if branch == 'master'
      @git.checkout
      @git.pull 'origin', 'master'
    elsif branch == @git.current_branch
      @git.pull *(branch.split('/'))
    else
      if @git.branches.map(&:name).include?(branch)
        @git.checkout(branch)
      else
        @git.checkout(branch, :new_branch => branch.gsub('remotes/', '').gsub('/', '-'))
      end
    end
  end
end

class FeatureBranchChanger < Sinatra::Base
  enable :inline_templates
  set :toplevel_dir, File.expand_path(File.dirname(__FILE__)+ '/../')

  get '/' do
    git = GitOperator.new(settings.toplevel_dir)

    @current_branch = git.get_current_branch
    @other_branches = git.get_other_branches

    erb :default
  end

  post '/git_checkout' do
    git = GitOperator.new(settings.toplevel_dir)
    current_branch = git.get_current_branch

    git.fetch_remotes
    git.checkout_remote_branch_head params[:branch] if params[:branch]
    current_branch.delete unless current_branch.name == 'master'

    redirect '/'
  end
end

FeatureBranchChanger.run!

__END__
@@default
<html>
  <head>
    <title>feature checker</title>
  </head>
  <body>  
    <p>
      <strong>Current branch</strong>: <%= @current_branch %>
    </p>
    <div>
      <form action="/git_checkout" method="post">
        <select name="branch">
          <option value="<%= @current_branch.name %>">
            * <%= @current_branch.name %>
          </option>
          <% @other_branches.each do |branch| %>
            <option value="<%= branch %>">
               <%= branch %>
             </option>
          <% end %>
        </select>
        <input type="submit" value="change branch" />
      </form>
    </div>
  </body>
</html>
