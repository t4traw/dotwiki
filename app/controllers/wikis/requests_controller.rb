class Wikis::RequestsController < ApplicationController
  include OnlyMaintainers
  helper_method :current_user_is_maintainer

  before_action :set_wiki
  before_action :set_page
  before_action :set_request, only: [:show, :edit, :update, :destroy]
  before_action :check_same_user, only: [:edit, :update, :destroy]
  before_action :only_maintainers, only: [:quick_merge, :adjust, :adjust_merge, :reject]
  skip_before_action :require_login, only: [:index, :show]

  def index
    @requests = @wiki.pages.find(params[:wiki_page_id]).requests
  end

  def show
    before = @page.histories.find(@request.history_id)
    @can_quick_merge = @page.latest_history.id == before.id
    @diffy = Diffy::Diff.new(before.content, @request.content, context: 1,
      include_plus_and_minus_in_html: true).to_s(:html_simple)
  end

  def new
    @request = Request.new(
      content: @page.latest_history.content
    )
  end

  def create
    diff = Diff::LCS.sdiff(@page.latest_history.content.lines, request_params[:content].lines)

    @request = Request.new(
      wiki_id: @wiki.id,
      page_id: @page.id,
      history_id: @page.latest_history.id,
      user_id: current_user.id,
      content: request_params[:content],
      comment: request_params[:comment],
    )
    
    if @request.save
      redirect_to wiki_page_request_path(@wiki, @page, @request), notice: t('.notice')
    else
      render :new
    end
  end

  def edit
  end

  def update
    page = Page.find(params[:wiki_page_id])
    diff = Diff::LCS.sdiff(page.latest_history.content.lines, request_params[:content].lines)

    if @request.update(content: request_params[:content])
      redirect_to wiki_page_request_path(@wiki, @page, @request), notice: t('.notice')
    else
      render :edit
    end
  end

  def destroy
    request = @page.requests.find(params[:id])
    request.destroy
    redirect_to wiki_page_requests_path(@wiki, @page), notice: t('.notice')
  end

  def merge
    request = @page.requests.find(params[:request_id])
    if @page.histories.create(user_id: request.user.id, content: params[:content], comment: request.comment)
      request.destroy
      redirect_to wiki_page_path(@wiki, @page), notice: t('.notice')
      # TODO Notificationクラスを追加して通知する
    else
      redirect_to wiki_page_requests_path(@wiki, @page), alert: t('.alert')
    end
  end

  def adjust
    @request = @page.requests.find(params[:request_id])
    before = @page.histories.find(@request.history_id)
    @can_quick_merge = @page.latest_history.id == before.id
    @diffy = Diffy::Diff.new(before.content, @request.content, context: 1,
      include_plus_and_minus_in_html: true).to_s(:html_simple)
  end

  def reject
    request = @page.requests.find(params[:request_id])
    request.destroy
    redirect_to wiki_page_requests_path(@wiki, @page), notice: t('.notice')
  end

  private
    def request_params
      params.require(:request).permit(:wiki_id, :wiki_page_id, :content, :comment)
    end

    def set_wiki
      @wiki = Wiki.find(params[:wiki_id])
      gon.wiki_id = @wiki.id
      gon.wathing_wiki = current_user.watches.find_by(wiki_id: @wiki.id) if current_user
    end

    def set_page
      @page = @wiki.pages.find(params[:wiki_page_id])
    end

    def set_request
      @request = @page.requests.find(params[:id])
    end

    def check_same_user
      unless current_user == @request.user
        redirect_to wiki_page_path(@wiki, @page)
      end
    end
end
