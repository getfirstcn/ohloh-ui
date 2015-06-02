require 'test_helper'

class KudosControllerTest < ActionController::TestCase
  let(:api_key) { create(:api_key) }
  let(:client_id) { api_key.oauth_application.uid }

  before do
    @kudo = create(:kudo)
    create(:kudo_with_name, sender: @kudo.account)
    sent1 = create(:kudo, sender: @kudo.account)
    create(:kudo, account: sent1.account, sender: @kudo.account)
    person = create(:person)
    create(:kudo, sender: @kudo.account, account: sent1.account, name: person.name, project: person.project)
    @request.env['HTTP_REFERER'] = '/'
  end

  # index action
  it 'index should not require a current user' do
    login_as nil
    get :index, account_id: @kudo.account
    must_respond_with :ok
  end

  it 'index should not offer way to rescind kudos to unlogged users' do
    login_as nil
    get :index, account_id: @kudo.account
    must_select 'i.rescind-kudos', false
  end

  it 'index should offer way to rescind kudos to account' do
    login_as @kudo.account
    get :index, account_id: @kudo.account
    must_select 'i.rescind-kudos', true
  end

  it 'index should offer way to rescind kudos to sender' do
    login_as @kudo.sender
    get :index, account_id: @kudo.account
    must_select 'i.rescind-kudos', true
  end

  it 'index should offer way to give kudos to random user' do
    login_as create(:account)
    get :index, account_id: @kudo.account
    must_select 'i.rescind-kudos', false
  end

  it 'index should not respond to xml format without an api_key' do
    login_as nil
    get :index, account_id: @kudo.account, format: :xml
    must_respond_with :unauthorized
  end

  it 'index should not respond to xml format with a banned api_key' do
    api_key.update!(status: ApiKey::STATUS_DISABLED)

    get :index, account_id: @kudo.account, api_key: client_id, format: :xml

    must_respond_with :unauthorized
  end

  it 'index should not respond to xml format with an over-limit api_key' do
    api_key.update! daily_count: 999_999

    get :index, account_id: @kudo.account, api_key: client_id, format: :xml

    must_respond_with :unauthorized
  end

  it 'index should respond to xml format' do
    login_as nil
    get :index, account_id: @kudo.account, api_key: client_id, format: :xml
    must_respond_with :ok
  end

  # sent action
  it 'sent should not respond to xml format without an api_key' do
    login_as nil
    get :sent, account_id: @kudo.account, format: :xml
    must_respond_with :unauthorized
  end

  it 'sent should not respond to xml format with a banned api_key' do
    login_as nil
    api_key.update!(status: ApiKey::STATUS_DISABLED)

    get :sent, account_id: @kudo.account, api_key: client_id, format: :xml
    must_respond_with :unauthorized
  end

  it 'sent should not respond to xml format with an over-limit api_key' do
    login_as nil
    api_key.update! daily_count: 999_999

    get :sent, account_id: @kudo.account, api_key: client_id, format: :xml
    must_respond_with :unauthorized
  end

  it 'sent should respond to xml format' do
    login_as nil
    get :sent, account_id: @kudo.account, api_key: client_id, format: :xml
    must_respond_with :ok
  end

  # new action
  it 'new should require a current user' do
    login_as nil
    get :new, account_id: create(:account).id
    must_respond_with :redirect
    must_redirect_to new_session_path
  end

  it 'new should accept account_id' do
    login_as create(:account)
    get :new, account_id: create(:account).id
    must_respond_with :ok
  end

  it 'new should accept contribution_id' do
    login_as create(:account)
    get :new, contribution_id: create(:person).id
    must_respond_with :ok
  end

  # create action
  it 'create should require a current user' do
    login_as nil
    post :create, kudo: { account_id: create(:account).id }
    must_respond_with :redirect
    must_redirect_to new_session_path
  end

  it 'create should not allow user to kudo themselves' do
    account = create(:account)
    login_as account
    post :create, kudo: { account_id: account.id }
    must_respond_with 302
    Kudo.where(account_id: account.id).count.must_equal 0
  end

  it 'create should allow user to kudo someone else' do
    account = create(:account)
    login_as create(:account)
    post :create, kudo: { account_id: account.id }
    must_respond_with 302
    Kudo.where(account_id: account.id).count.must_equal 1
  end

  it 'create should allow user to kudo a contribution' do
    person = create(:person)
    login_as create(:account)
    post :create, kudo: { contribution_id: person.id }
    must_respond_with 302
    Kudo.where(project_id: person.project_id).count.must_equal 1
  end

  # destroy action
  it 'destroy should require a current user' do
    kudo = create(:kudo)
    login_as nil
    delete :destroy, id: kudo.id
    must_respond_with :redirect
    must_redirect_to new_session_path
    Kudo.where(id: kudo.id).count.must_equal 1
  end

  it 'destroy should allow target to delete kudo' do
    kudo = create(:kudo)
    login_as kudo.account
    delete :destroy, id: kudo.id
    must_respond_with 302
    Kudo.where(id: kudo.id).count.must_equal 0
  end

  it 'destroy should allow sender to delete kudo' do
    kudo = create(:kudo)
    login_as kudo.sender
    delete :destroy, id: kudo.id
    must_respond_with 302
    Kudo.where(id: kudo.id).count.must_equal 0
  end

  it 'destroy should not allow random user to delete kudo' do
    kudo = create(:kudo)
    login_as create(:account)
    delete :destroy, id: kudo.id
    must_respond_with 302
    Kudo.where(id: kudo.id).count.must_equal 1
  end
end
