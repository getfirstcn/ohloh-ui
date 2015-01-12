require 'test_helper'

class PostsController < ApplicationController
  before_action :session_required, only: [:new, :create, :edit, :update]
  before_action :admin_session_required, only: [:destroy]
  before_action :find_forum_and_topic_records
  before_action :find_post_record, only: [:edit, :update, :destroy]

  def index
    @posts = @topic.posts
    redirect_to forum_topic_path(@forum, @topic)
  end

  def new
    @post = @topic.posts.build
  end

  def create
    @post = @topic.posts.build(post_params)
    respond_to do |format|
      if @post.save
        format.html { redirect_to forum_topic_path(@forum, @topic), flash: { success: t('.success') } }
      else
        format.html { redirect_to forum_topic_path(@forum, @topic), flash: { error: t('.error') } }
      end
    end
  end

  def edit
    redirect_to forum_topic_path(@forum, @topic) if current_user.id != @post.account_id && current_user_is_admin? == false
  end

  def update
    respond_to do |format|
      if @post.update(post_params)
        format.html { redirect_to forum_topic_path(@forum, @topic), flash: { success: t('.success') } }
      else
        format.html { redirect_to forum_topic_path(@forum, @topic), flash: { error: t('.error') } }
      end
    end
  end

  def destroy
    @post.destroy
    respond_to do |format|
      format.html { redirect_to forum_topic_path(@forum, @topic) }
    end
  end

  private

  def find_post_record
    find_forum_and_topic_records
    @post= @topic.posts.find_by(id: params[:id])
  end

  def find_forum_and_topic_records
    @forum = Forum.find_by(id: params[:forum_id])
    @topic = @forum.topics.find_by(id: params[:topic_id])
  end

  def post_params
    params.require(:post).permit(:topic_id, :account_id, :body)
  end
end