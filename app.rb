require 'sinatra'
require 'sinatra/flash'

get '/' do
  @current_branch, @remote_branches =
    GitOperator.get_current_branch_and_other_branches
  erb :index
end

post '/git_checkout' do
  GitOperator.checkout_remote_branch_head(
    params[:branch]
  ) if params[:branch]

  redirect '/'
end

module GitCommands
  def git_checkout branch = 'master'
    `git checkout -b #{branch}`
  end

  def git_fetch_all
    `git fetch --all`
  end

  def git_branch_all 
    `git branch -a`
  end
  
  def git_branch_delete branch
    `git branch -D #{branch}`
  end
end

class GitOperator
  class << self
    include GitCommands

    def get_current_branch_and_other_branches
      return unless outputs = git_branch_all.split("\n")
      current_branch = select_current_branch(outputs)
      other_branches = select_branches_without_current_branch(outputs)
      return current_branch, other_branches
    end

    def checkout_remote_branch_head branch
      current_branch, remote_branches =
        get_current_branch_and_other_branches
      git_fetch_all
      git_checkout if current_branch == branch
      git_checkout branch
      git_branch_delete branch.sub('(origin)/','')
    end

    private

    def select_current_branch outputs
      outputs.select do |branch|
        branch =~ /\A\*\s.+/
      end.first.split[1]
    end

    def select_branches_without_current_branch outputs
      replacer = proc {|s| s.sub(%r|remotes/|, '') }
      outputs.select do |branch|
        branch !~ /\A\*\s.+/
      end.map(&:strip).map(&replacer)
    end
  end
end

__END__
@@index
<html>
  <head>
    <title>feature checker</title>
  </head>
  <body>
    <h4><%= @current_branch %></h4>
    <div>
      <form action="/git_checkout" method="post">
        <select name="branch">
          <% @remote_branches.each do |branch| %>
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
