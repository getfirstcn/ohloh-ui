require 'test_helper'

describe 'ProjectsController' do
  let(:api_key) { create(:api_key) }
  let(:client_id) { api_key.oauth_application.uid }

  # index
  it 'index should handle query param for unlogged users' do
    project1 = create(:project, name: 'Foo', description: Faker::Lorem.sentence(90))
    project2 = create(:project, name: 'FooBar', description: Faker::Lorem.sentence(90))
    project3 = create(:project, name: 'Goobaz', description: Faker::Lorem.sentence(90))
    login_as nil
    get :index, query: 'foo'
    must_respond_with :ok
    must_select "div.well#project_#{project1.id}", true
    must_select "div.well#project_#{project2.id}", true
    must_select "div.well#project_#{project3.id}", false
  end

  it 'index should handle query param that matches no project' do
    get :index, query: 'qwertyuioplkjhgfdsazxcvbnm'
    must_respond_with :ok
    must_select 'div.advanced_search_tips', true
  end

  it 'index should handle query param sorting by new' do
    create(:project, name: 'Foo_new', description: 'second', created_at: Time.current - 3.hours)
    create(:project, name: 'FooBar_new', description: 'first')
    login_as nil
    get :index, query: 'foo', sort: 'new'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  it 'index should handle query param sorting by "activity_level"' do
    create(:project, name: 'Foo_activity_level', description: 'second', activity_level_index: 0)
    create(:project, name: 'FooBar_activity_level', description: 'first', activity_level_index: 20)
    login_as nil
    get :index, query: 'foo', sort: 'activity_level'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  it 'index should handle query param sorting by "users"' do
    create(:project, name: 'Foo_users', description: 'second', user_count: 1)
    create(:project, name: 'FooBar_users', description: 'first', user_count: 20)
    login_as nil
    get :index, query: 'foo', sort: 'users'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  it 'index should handle query param sorting by "rating"' do
    create(:project, name: 'Foo_rating', description: 'second', rating_average: 2)
    create(:project, name: 'FooBar_rating', description: 'first', rating_average: 4)
    login_as nil
    get :index, query: 'foo', sort: 'rating'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  it 'index should handle query param sorting by "active_committers"' do
    create(:project, name: 'Foo_active_committers', description: 'second', active_committers: 23)
    create(:project, name: 'FooBar_active_committers', description: 'first', active_committers: 42)
    login_as nil
    get :index, query: 'foo', sort: 'active_committers'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  it 'index should handle query param with atom format' do
    create(:project, name: 'Foo_atom', description: 'second', rating_average: 2)
    create(:project, name: 'FooBar_atom', description: 'first', rating_average: 4)
    login_as nil
    get :index, query: 'foo', sort: 'rating', format: 'atom'
    must_respond_with :ok
    nodes = Nokogiri::XML(response.body).css('entry')
    nodes.length.must_equal 2
    nodes[0].css('title').children.to_s.must_equal 'FooBar_atom'
    nodes[1].css('title').children.to_s.must_equal 'Foo_atom'
  end

  it 'index should not respond to xml format without an api_key' do
    login_as nil
    get :index, query: 'foo', sort: 'rating', format: 'xml'
    must_respond_with :unauthorized
  end

  it 'index should not respond to xml format with a banned api_key' do
    login_as nil

    api_key.update!(status: ApiKey::STATUS_DISABLED)
    get :index, query: 'foo', sort: 'rating', api_key: client_id, format: :xml
    must_respond_with :unauthorized
  end

  it 'index should not respond to xml format with an over-limit api_key' do
    login_as nil
    api_key.update! daily_count: 999_999
    get :index, query: 'foo', sort: 'rating', api_key: client_id, format: :xml
    must_respond_with :unauthorized
  end

  it 'index should respond to xml format' do
    create(:project, name: 'Foo_xml', description: 'second', rating_average: 2)
    create(:project, name: 'FooBar_xml', description: 'first', rating_average: 4)
    login_as nil
    get :index, query: 'foo', sort: 'rating', api_key: client_id, format: :xml
    must_respond_with :ok
    nodes = Nokogiri::XML(response.body).css('project')
    nodes.length.must_equal 2
    nodes[0].css('name').children.to_s.must_equal 'FooBar_xml'
    nodes[1].css('name').children.to_s.must_equal 'Foo_xml'
  end

  it 'index should respond to xml format with list of ids' do
    project1 = create(:project, name: 'Baz_xml', description: 'second', rating_average: 2)
    project2 = create(:project, name: 'BazBar_xml', description: 'first', rating_average: 4)
    login_as nil
    get :index, ids: "#{project1.id},#{project2.id}", api_key: client_id, format: :xml
    must_respond_with :ok
    nodes = Nokogiri::XML(response.body).css('project')
    nodes.length.must_equal 2
    nodes[0].css('name').children.to_s.must_equal 'Baz_xml'
    nodes[1].css('name').children.to_s.must_equal 'BazBar_xml'
  end

  it 'index should gracefully handle garbage numeric ids' do
    login_as nil
    get :index, ids: '111112222222', api_key: client_id, format: :xml
    must_respond_with :not_found
  end

  it 'index should gracefully handle garbage non-numeric ids' do
    login_as nil
    get :index, ids: 'baal_the_destroyer', api_key: client_id, format: :xml
    must_respond_with :ok
    nodes = Nokogiri::XML(response.body).css('project')
    nodes.length.must_equal 0
  end

  it 'index should limit maximum returned to 25' do
    projects = (0...50).map { |_| create(:project) }
    login_as nil
    get :index, ids: projects.map(&:id).join(','), per_page: 50, api_key: client_id, format: :xml
    must_respond_with :ok
    nodes = Nokogiri::XML(response.body).css('project')
    nodes.length.must_equal 25
  end

  it 'index should support pagination' do
    projects = (0...10).map { |_| create(:project) }
    login_as nil
    get :index, ids: projects.map(&:id).join(','), page: 2, per_page: 5, api_key: client_id, format: :xml
    must_respond_with :ok
    nodes = Nokogiri::XML(response.body).css('project')
    nodes.length.must_equal 5
    nodes[0].css('id').children.to_s.to_i.must_equal projects[5].id
  end

  it 'index should handle account sorting by "new"' do
    project1 = create(:project, name: 'Foo_accounts_new', description: 'second', created_at: Time.current - 3.hours)
    project2 = create(:project, name: 'FooBar_accounts_new', description: 'first')
    login_as nil
    manager = create(:account)
    create(:manage, account: manager, target: project1)
    create(:manage, account: manager, target: project2)
    get :index, account_id: manager.to_param, sort: 'new'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  it 'index should handle account sorting by "users"' do
    project1 = create(:project, name: 'Foo_accounts_users', description: 'second', user_count: 1)
    project2 = create(:project, name: 'FooBar_accounts_users', description: 'first', user_count: 20)
    manager = create(:account)
    create(:manage, account: manager, target: project1)
    create(:manage, account: manager, target: project2)
    login_as nil
    get :index, account_id: manager.to_param, sort: 'users'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  it 'index should handle account sorting by "project_name"' do
    project1 = create(:project, name: 'ZZZ_second_project_name')
    project2 = create(:project, name: 'AAA_first_project_name')
    manager = create(:account)
    create(:manage, account: manager, target: project1)
    create(:manage, account: manager, target: project2)
    login_as nil
    get :index, account_id: manager.to_param, sort: 'project_name'
    must_respond_with :ok
    response.body.must_match(/first.*second/m)
  end

  describe 'show' do
    it 'show should render for unlogged users' do
      project = create(:project)
      login_as nil
      get :show, id: project.to_param
      must_respond_with :ok
    end

    it 'show should render for projects that have been analyzed' do
      project = create(:project)
      af_1 = create(:activity_fact, analysis: project.best_analysis, code_added: 8_000, comments_added: 8_000)
      create(:factoid, analysis: project.best_analysis, language: af_1.language)
      af_2 = create(:activity_fact, analysis: project.best_analysis)
      create(:factoid, analysis: project.best_analysis, language: af_2.language)
      af_3 = create(:activity_fact, analysis: project.best_analysis)
      create(:factoid, analysis: project.best_analysis, language: af_3.language)
      af_4 = create(:activity_fact, analysis: project.best_analysis)
      create(:factoid, analysis: project.best_analysis, language: af_4.language)
      ats = project.best_analysis.all_time_summary
      ats.update_attributes(recent_contributors: [create(:person).id, create(:person).id])
      cf = create(:commit_flag)
      create(:analysis_sloc_set, analysis: project.best_analysis, sloc_set: cf.sloc_set)
      login_as create(:admin)
      get :show, id: project.to_param
      must_respond_with :ok
    end

    it 'must render successfully when analysis has nil dates' do
      project = create(:project)
      project.best_analysis.update! min_month: nil, max_month: nil, logged_at: nil,
                                    first_commit_time: nil, last_commit_time: nil

      get :show, id: project.to_param

      must_respond_with :ok
    end
  end

  # new
  it 'new should require a current user' do
    login_as nil
    get :new
    must_respond_with :redirect
    must_redirect_to new_session_path
    flash[:notice].must_equal I18n.t('sessions.message_html', href: new_account_path)
  end

  it 'new should render for logged users' do
    login_as create(:account)
    get :new
    must_respond_with :ok
  end

  # check_forge
  it 'check_forge should require a current user' do
    login_as nil
    post :check_forge, codelocation: 'http://cnn.com'
    must_respond_with :redirect
    must_redirect_to new_session_path
    flash[:notice].must_equal I18n.t('sessions.message_html', href: new_account_path)
  end

  it 'check_forge should gracefully handle duplicate projects detected' do
    VCR.use_cassette('ProjectControllerCheckForge-rails') do
      proj = create(:project)
      repo = create(:repository, url: 'git://github.com/rails/rails.git', forge_id: forges(:github).id,
                                 owner_at_forge: 'rails', name_at_forge: 'rails')
      create(:enlistment, project: proj, repository: repo)
      login_as create(:account)
      post :check_forge, codelocation: 'https://github.com/rails/rails'
      must_respond_with :ok
      must_select "#project_#{proj.id}", 1
      must_select 'form#new_project', 0
      response.body.must_match 'already'
    end
  end

  it 'check_forge should gracefully handle forge timeout errors' do
    VCR.use_cassette('ProjectControllerCheckForge-rails') do
      proj = create(:project)
      repo = create(:repository, url: 'git://github.com/rails/rails.git', forge_id: forges(:github).id,
                                 owner_at_forge: 'rails', name_at_forge: 'rails')
      create(:enlistment, project: proj, repository: repo)
      login_as create(:account)
      Forge::Match.any_instance.expects(:project).raises Timeout::Error
      post :check_forge, codelocation: 'https://github.com/rails/rails', bypass: true
      must_respond_with :ok
      must_select "#project_#{proj.id}", 0
      must_select 'form#new_project', 1
      response.body.must_match I18n.t('projects.check_forge.forge_time_out', name: forges(:github).name)
    end
  end

  it 'check_forge should allow creating a project that already matches an existing project' do
    VCR.use_cassette('ProjectControllerCheckForge-rails') do
      proj = create(:project)
      repo = create(:repository, url: 'git://github.com/rails/rails.git', forge_id: forges(:github).id,
                                 owner_at_forge: 'rails', name_at_forge: 'rails')
      create(:enlistment, project: proj, repository: repo)
      login_as create(:account)
      post :check_forge, codelocation: 'https://github.com/rails/rails', bypass: true
      must_respond_with :ok
      must_select "#project_#{proj.id}", 0
      must_select 'form#new_project', 1
    end
  end

  # create
  it 'create should require a current user' do
    login_as nil
    post :create, project: { name: 'Fail', url_name: 'fail', description: 'It fails.' }
    must_respond_with :redirect
    must_redirect_to new_session_path
    flash[:notice].must_equal I18n.t('sessions.message_html', href: new_account_path)
  end

  it 'create should persist a valid project to the database' do
    account = create(:account)
    license1 = create(:license)
    license2 = create(:license)
    login_as account
    post :create, project: { name: 'Cool Beans', url_name: 'cool-beans', description: 'cool beans app',
                             url: 'http://a.com/', download_url: 'http://b.com/', managed_by_creator: '1',
                             project_licenses_attributes: [{ license_id: license1.id }, { license_id: license2.id }],
                             enlistments_attributes: [repository_attributes: { type: 'GitRepository',
                                                                               url: 'git://a.com/cb.git',
                                                                               branch_name: 'master' }] }
    must_respond_with 302
    project = Project.where(url_name: 'cool-beans').last
    project.wont_equal nil
    project.name.must_equal 'Cool Beans'
    project.url.must_equal 'http://a.com/'
    project.download_url.must_equal 'http://b.com/'
    project.active_managers.must_equal [account]
    project.licenses.map(&:id).sort.must_equal [license1.id, license2.id].sort
    project.repositories.length.must_equal 1
    project.repositories[0].type.must_equal 'GitRepository'
    project.repositories[0].url.must_equal 'git://a.com/cb.git'
    project.repositories[0].branch_name.must_equal 'master'
  end

  it 'create should allow no download_url' do
    account = create(:account)
    license1 = create(:license)
    license2 = create(:license)
    login_as account
    post :create, project: { name: 'Cool Beans', url_name: 'cool-beans', description: 'cool beans app',
                             url: 'http://a.com/', download_url: '', managed_by_creator: '1',
                             project_licenses_attributes: [{ license_id: license1.id }, { license_id: license2.id }],
                             enlistments_attributes: [repository_attributes: { type: 'GitRepository',
                                                                               url: 'git://a.com/cb.git',
                                                                               branch_name: 'master' }] }
    must_respond_with 302
    project = Project.where(url_name: 'cool-beans').last
    project.wont_equal nil
    project.name.must_equal 'Cool Beans'
    project.url.must_equal 'http://a.com/'
    project.download_url.must_equal nil
    project.active_managers.must_equal [account]
    project.licenses.map(&:id).sort.must_equal [license1.id, license2.id].sort
    project.repositories.length.must_equal 1
    project.repositories[0].type.must_equal 'GitRepository'
    project.repositories[0].url.must_equal 'git://a.com/cb.git'
    project.repositories[0].branch_name.must_equal 'master'
  end

  it 'create should allow no licenses' do
    account = create(:account)
    login_as account
    post :create, project: { name: 'Cool Beans', url_name: 'cool-beans', description: 'cool beans app',
                             url: 'http://a.com/', download_url: 'http://b.com/', managed_by_creator: '1',
                             project_licenses_attributes: [],
                             enlistments_attributes: [repository_attributes: { type: 'GitRepository',
                                                                               url: 'git://a.com/cb.git',
                                                                               branch_name: 'master' }] }
    must_respond_with 302
    project = Project.where(url_name: 'cool-beans').last
    project.wont_equal nil
    project.name.must_equal 'Cool Beans'
    project.url.must_equal 'http://a.com/'
    project.download_url.must_equal 'http://b.com/'
    project.active_managers.must_equal [account]
    project.licenses.must_equal []
    project.repositories.length.must_equal 1
    project.repositories[0].type.must_equal 'GitRepository'
    project.repositories[0].url.must_equal 'git://a.com/cb.git'
    project.repositories[0].branch_name.must_equal 'master'
  end

  it 'create should allow the creator not being automatically the manager' do
    license1 = create(:license)
    license2 = create(:license)
    login_as create(:account)
    post :create, project: { name: 'Cool Beans', url_name: 'cool-beans', description: 'cool beans app',
                             url: 'http://a.com/', download_url: 'http://b.com/', managed_by_creator: '0',
                             project_licenses_attributes: [{ license_id: license1.id }, { license_id: license2.id }],
                             enlistments_attributes: [repository_attributes: { type: 'GitRepository',
                                                                               url: 'git://a.com/cb.git',
                                                                               branch_name: 'master' }] }
    must_respond_with 302
    project = Project.where(url_name: 'cool-beans').last
    project.wont_equal nil
    project.name.must_equal 'Cool Beans'
    project.url.must_equal 'http://a.com/'
    project.download_url.must_equal 'http://b.com/'
    project.active_managers.must_equal []
    project.licenses.map(&:id).sort.must_equal [license1.id, license2.id].sort
    project.repositories.length.must_equal 1
    project.repositories[0].type.must_equal 'GitRepository'
    project.repositories[0].url.must_equal 'git://a.com/cb.git'
    project.repositories[0].branch_name.must_equal 'master'
  end

  it 'create should gracefully handle validation errors' do
    login_as create(:account)
    post :create, project: { name: '' }
    must_respond_with :unprocessable_entity
    must_select 'form#new_project', 1
    must_select 'p.error'
  end

  # edit
  it 'edit should disable save button for unlogged users' do
    login_as nil
    get :edit, id: create(:project).id
    must_respond_with :ok
    must_select 'input.save', 0
    must_select '.needs_login.save', 1
  end

  it 'edit should enable save button for managers' do
    project = create(:project)
    manager = create(:account)
    Manage.create(target: project, account: manager)
    login_as manager
    get :edit, id: project.id
    must_respond_with :ok
    must_select 'input.save', 1
    must_select '.disabled.save', 0
  end

  it 'edit should enable save button for admins' do
    login_as create(:admin)
    get :edit, id: create(:project).id
    must_respond_with :ok
    must_select 'input.save', 1
    must_select '.disabled.save', 0
  end

  # update
  it 'update should refuse unauthorized attempts' do
    project = create(:project)
    login_as nil
    put :update, id: project.id, project: { name: 'KoolOSSProject' }
    must_respond_with :redirect
    must_redirect_to new_session_path
    flash[:notice].must_equal I18n.t('sessions.message_html', href: new_account_path)
    project.reload.name.wont_equal 'KoolOSSProject'
  end

  it 'update should persist changes' do
    project = create(:project)
    login_as create(:admin)
    put :update, id: project.id, project: { name: 'KoolOSSProject' }
    must_respond_with 302
    project.reload.name.must_equal 'KoolOSSProject'
  end

  it 'update should handle invalid params and render the edit action' do
    project = create(:project, name: 'KoolOSSProject123')
    login_as create(:admin)
    put :update, id: project.id, project: { name: '' }
    must_respond_with :unprocessable_entity
    project.reload.name.must_equal 'KoolOSSProject123'
    must_select 'input.save', 1
    must_select 'p.error[rel="name"]', 1
  end

  it 'update should handle blank url_names gracefully and render the edit action' do
    project = create(:project)
    login_as create(:admin)
    put :update, id: project.id, project: { url_name: '' }
    must_respond_with :unprocessable_entity
    project.reload.url_name.blank?.must_equal false
    must_respond_with :unprocessable_entity
    must_select 'input.save', 1
    must_select 'p.error[rel="url_name"]', 1
  end

  # estimated_cost
  it 'estimated_cost should display for analyzed projects' do
    login_as nil
    get :estimated_cost, id: create(:project).id
    must_respond_with :success
    response.body.must_match I18n.t('projects.estimated_cost.project_cost_calculator')
    must_select '.no_analysis_message', 0
  end

  it 'estimated_cost should display for unanalyzed projects' do
    project = create(:project)
    project.update_attributes(best_analysis_id: nil)
    login_as nil
    get :estimated_cost, id: project.id
    must_respond_with :success
    response.body.wont_match I18n.t('projects.estimated_cost.project_cost_calculator')
    must_select '.no_analysis_message', 1
  end

  it 'should show the project users page' do
    project = create(:project, logo: nil)
    account = create(:account)
    create(:stack_entry, stack: create(:stack, account: account), project: project)
    create(:stack_entry, stack: create(:stack, account: account), project: project)
    get :users, id: project.id
    must_respond_with :success
    must_select '.advanced_search_tips', 0
    assigns(:accounts).count.must_equal 2
  end

  it 'should search for a valid account' do
    project = create(:project, logo: nil)
    account1 = create(:account)
    account2 = create(:account)
    create(:stack_entry, stack: create(:stack, account: account1), project: project)
    create(:stack_entry, stack: create(:stack, account: account2), project: project)

    get :users, id: project.id, query: account1.name
    must_respond_with :success
    must_select '.advanced_search_tips', 0
    assigns(:accounts).count.must_equal 1
  end

  it 'should not list a invalid search term' do
    project = create(:project, logo: nil)
    get :users, id: project.id, query: 'unknown_text_to_seach'
    must_respond_with :success
    must_select '.advanced_search_tips', 1
    assigns(:accounts).count.must_equal 0
  end

  it 'should show the permission alert when not logged in while accessing the setting page' do
    project = create(:project, logo: nil)
    get :settings, id: project.id
    must_respond_with :success
    flash[:notice].must_equal I18n.t('permissions.must_log_in')
  end

  it 'should not show the permission alert when logged in while accessing the setting page' do
    login_as create(:admin)
    project = create(:project, logo: nil)
    get :settings, id: project.id
    must_respond_with :success
  end

  describe 'map' do
    it 'map should display for unlogged in users' do
      login_as nil
      get :map, id: create(:project).to_param
      must_respond_with :success
      must_select '#map', 1
    end

    it 'must render successfully when no analysis' do
      Project.any_instance.stubs(:best_analysis).returns(NilAnalysis.new)

      get :map, id: create(:project).to_param

      must_respond_with :success
    end
  end

  # similar_by_tags
  it 'similar_by_tags should display for projects with no tags' do
    get :similar_by_tags, id: create(:project).to_param
    must_respond_with :success
    response.body.must_match I18n.t('projects.show.similar_by_tags.none')
  end

  it 'similar_by_tags should invite users to add tags for projects with no tags' do
    login_as create(:account)
    get :similar_by_tags, id: create(:project).to_param
    must_respond_with :success
    response.body.must_match I18n.t('projects.show.similar_by_tags.add_some_tags')
  end

  it 'similar_by_tags should display related projects' do
    project1 = create(:project, name: 'California')
    project2 = create(:project, name: 'Oregon')
    project3 = create(:project, name: 'Washington')
    create(:project, name: 'Arizona')
    tag = create(:tag)
    create(:tagging, taggable: project1, tag: tag)
    create(:tagging, taggable: project2, tag: tag)
    create(:tagging, taggable: project3, tag: tag)
    get :similar_by_tags, id: project1.to_param
    must_respond_with :success
    response.body.wont_match 'California'
    response.body.must_match 'Oregon'
    response.body.must_match 'Washington'
    response.body.wont_match 'Arizona'
  end

  it '#similar should return similar projects (both by tags and stacks)' do
    project1 = create(:project)
    project2 = create(:project)
    project3 = create(:project)
    stack1 = create(:stack)
    stack2 = create(:stack)
    stack3 = create(:stack)

    create(:stack_entry, stack: stack1, project: project1)
    create(:stack_entry, stack: stack1, project: project2)
    create(:stack_entry, stack: stack1, project: project3)
    create(:stack_entry, stack: stack2, project: project1)
    create(:stack_entry, stack: stack2, project: project2)
    create(:stack_entry, stack: stack2, project: project3)
    create(:stack_entry, stack: stack3, project: project1)
    create(:stack_entry, stack: stack3, project: project2)
    create(:stack_entry, stack: stack3, project: project3)

    tag = create(:tag)
    create(:tagging, tag: tag, taggable: project1)
    create(:tagging, tag: tag, taggable: project2)
    create(:tagging, tag: tag, taggable: project3)

    get :similar, id: project1.to_param

    assigns(:project).must_equal project1
    assigns(:similar_by_tags).must_include project2
    assigns(:similar_by_tags).must_include project3
    assigns(:similar_by_stacks).must_include project2
    assigns(:similar_by_stacks).must_include project3
  end

  describe 'oauth' do
    describe 'index' do
      let(:token) { stub('acceptable?' => true, application: stub(uid: api_key.oauth_application.uid)) }

      it 'wont allow access with a banned api_key' do
        @controller.stubs(:doorkeeper_token).returns(token)
        api_key.update!(status: ApiKey::STATUS_DISABLED)

        get :index, format: :xml

        must_respond_with :unauthorized
      end

      it 'wont allow access with an over-limit api_key' do
        @controller.stubs(:doorkeeper_token).returns(token)
        api_key.update! daily_count: 999_999

        get :index, format: :xml

        must_respond_with :unauthorized
      end

      it 'wont allow access without oauth token' do
        get :index, format: :xml

        must_respond_with :unauthorized
      end

      it 'wont allow access for token matching no application' do
        token = stub('acceptable?' => true)
        @controller.stubs(:doorkeeper_token).returns(token)

        get :index, format: :xml

        must_respond_with :unauthorized
      end

      it 'must allow access for a valid token' do
        @controller.stubs(:doorkeeper_token).returns(token)
        create(:project, name: 'Foo_xml', description: 'second', rating_average: 2)
        create(:project, name: 'FooBar_xml', description: 'first', rating_average: 4)
        get :index, query: 'foo', sort: 'rating', format: :xml
        must_respond_with :ok
        nodes = Nokogiri::XML(response.body).css('project')
        nodes.length.must_equal 2
        nodes[0].css('name').children.to_s.must_equal 'FooBar_xml'
        nodes[1].css('name').children.to_s.must_equal 'Foo_xml'
      end
    end
  end
end
