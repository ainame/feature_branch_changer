require 'sinatra'
require 'sinatra/base'

module GitCommands
  def git_pull remote, branch
    `git pull #{remote} #{branch}`
  end

  def git_checkout_already_exists_branch branch
    `git checkout #{branch}`
  end

  def git_checkout_new_branch branch
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

    def get_current_and_other_branches
      return unless outputs = git_branch_all.split("\n")
      current_branch = select_current_branch(outputs)
      other_branches = select_branches_without_current_branch(outputs)
      return current_branch, other_branches
    end

    def checkout_remote_branch_head branch
      git_fetch_all

      current_branch, remote_branches =
        get_current_and_other_branches

      if branch == 'master'
        git_checkout_already_exists_branch 'master' unless
          current_branch == 'master'
        git_pull 'origin', 'master'
      elsif branch == current_branch
        git_checkout_already_exists_branch 'master'
        git_pull *(branch.split('/'))
      else
        git_checkout_new_branch(branch)
      end

      unless current_branch == 'master'
        git_branch_delete current_branch
      end
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

class FeatureBranchChanger < Sinatra::Base
  enable :inline_templates

  get '/' do
    @current_branch, @remote_branches =
      GitOperator.get_current_and_other_branches
    erb :default
  end

  post '/git_checkout' do
    GitOperator.checkout_remote_branch_head(
      params[:branch]
    ) if params[:branch]

    redirect '/'
  end
end

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
          <option value="<%= @current_branch%>">
            * <%= @current_branch%>
          </option>
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
