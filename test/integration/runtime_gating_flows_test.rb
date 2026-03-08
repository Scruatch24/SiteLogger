require "test_helper"

class RuntimeGatingFlowsTest < ActionDispatch::IntegrationTest
  test "free users can view categories in history without category management controls" do
    user = create_user(plan: "free", email: "free-history@example.com")
    category = create_category(user: user, name: "Legacy Category")
    log = create_log(user: user, invoice_number: 1001)
    log.categories << category

    sign_in user

    get history_path

    assert_response :success
    assert_includes response.body, "Legacy Category"
    assert_not_includes response.body, "delete-form-#{category.id}"
    assert_not_includes response.body, 'id="manage-body-categories"'
  end

  test "free users cannot create or delete categories" do
    user = create_user(plan: "free", email: "free-categories@example.com")
    category = create_category(user: user, name: "Existing Category")

    sign_in user

    assert_no_difference("Category.count") do
      post categories_path, params: {
        category: {
          name: "Blocked Category",
          icon_type: "premade",
          premade_icon: "star",
          color: "#000000"
        }
      }
    end
    assert_redirected_to history_path

    assert_no_difference("Category.count") do
      delete category_path(category)
    end
    assert_redirected_to history_path
    assert Category.exists?(category.id)
  end

  test "free users cannot mutate categories but can still update clients and use global pinning" do
    user = create_user(plan: "free", email: "free-log-mutations@example.com")
    category = create_category(user: user, name: "Locked Category")
    client = create_client(user: user, name: "Allowed Client")
    log = create_log(user: user, invoice_number: 1001)

    sign_in user

    patch update_categories_log_path(log), params: {
      category_ids: [ category.id ]
    }, as: :json

    assert_response :forbidden
    assert_equal [], log.reload.category_ids

    patch bulk_update_categories_logs_path, params: {
      log_ids: [ log.id ],
      added_category_ids: [],
      removed_category_ids: [],
      client_id: client.id
    }, as: :json

    assert_response :success
    assert_equal client.id, log.reload.client_id

    patch bulk_pin_logs_path, params: {
      log_ids: [ log.id ],
      category_id: category.id,
      pin: true
    }, as: :json

    assert_response :forbidden
    assert_not log.reload.pinned?

    patch bulk_pin_logs_path, params: {
      log_ids: [ log.id ],
      pin: true
    }, as: :json

    assert_response :success
    assert log.reload.pinned?
  end

  test "owned client and category ids are enforced in bulk log updates" do
    user = create_user(plan: "paid", email: "paid-owner@example.com")
    other_user = create_user(plan: "paid", email: "paid-other@example.com")
    foreign_client = create_client(user: other_user, name: "Foreign Client")
    foreign_category = create_category(user: other_user, name: "Foreign Category")
    log = create_log(user: user, invoice_number: 1001)

    sign_in user

    patch bulk_update_categories_logs_path, params: {
      log_ids: [ log.id ],
      added_category_ids: [ foreign_category.id ],
      removed_category_ids: [],
      client_id: foreign_client.id
    }, as: :json

    assert_response :success
    log.reload
    assert_equal [], log.category_ids
    assert_nil log.client_id
  end

  test "check-only export preflight does not create tracking events and still enforces limits" do
    user = create_user(plan: "free", email: "free-export-check@example.com")

    sign_in user

    assert_no_difference("TrackingEvent.count") do
      post "/track", params: {
        event_name: "invoice_exported",
        check_only: true,
        target_id: "123"
      }, as: :json
    end
    assert_response :success

    user.profile.export_limit.times do |idx|
      TrackingEvent.create!(event_name: "invoice_exported", user_id: user.id, ip_address: "127.0.0.1", target_id: idx.to_s)
    end

    assert_no_difference("TrackingEvent.count") do
      post "/track", params: {
        event_name: "invoice_exported",
        check_only: true,
        target_id: "456"
      }, as: :json
    end
    assert_response :too_many_requests
  end

  test "guests are redirected away from checkout" do
    get checkout_path

    assert_redirected_to new_user_registration_path
  end

  test "guest log actions require matching session id" do
    log = create_guest_log(session_id: "guest-session-a", ip_address: "127.0.0.1")

    patch update_status_log_path(log), params: {
      status: "sent",
      session_id: "guest-session-b"
    }, as: :json

    assert_response :not_found

    patch update_status_log_path(log), params: {
      status: "sent",
      session_id: "guest-session-a"
    }, as: :json

    assert_response :success
    assert_equal "sent", log.reload.status
  end

  test "guest export preflight is isolated by session id" do
    limit = Profile::EXPORT_LIMITS["guest"] || 2

    limit.times do |idx|
      TrackingEvent.create!(
        event_name: "invoice_exported",
        ip_address: "127.0.0.1",
        session_id: "guest-session-a",
        target_id: idx.to_s
      )
    end

    assert_no_difference("TrackingEvent.count") do
      post "/track", params: {
        event_name: "invoice_exported",
        check_only: true,
        session_id: "guest-session-b",
        target_id: "123"
      }, as: :json
    end
    assert_response :success

    assert_no_difference("TrackingEvent.count") do
      post "/track", params: {
        event_name: "invoice_exported",
        check_only: true,
        session_id: "guest-session-a",
        target_id: "456"
      }, as: :json
    end
    assert_response :too_many_requests
  end

  private

  def create_user(plan:, email:)
    password = "password123"
    user = User.create!(
      email: email,
      password: password,
      password_confirmation: password,
      confirmed_at: Time.current,
      name: email.split("@").first
    )

    Profile.create!(
      user: user,
      plan: plan,
      business_name: "Biz #{email}",
      phone: "123456789",
      email: email,
      address: "123 Main St",
      hourly_rate: 100,
      tax_rate: 18,
      currency: "USD",
      billing_mode: "hourly",
      tax_scope: "labor,materials_only"
    )

    user.reload
  end

  def create_log(user:, invoice_number:, client: "Client")
    Log.create!(
      user: user,
      client: client,
      date: "Mar 08, 2026",
      due_date: "Mar 15, 2026",
      time: "1",
      tasks: [],
      credits: [],
      billing_mode: "hourly",
      tax_scope: "labor,materials_only",
      currency: "USD",
      hourly_rate: 100,
      invoice_number: invoice_number,
      status: "draft"
    )
  end

  def create_guest_log(session_id:, ip_address:)
    Log.create!(
      user: nil,
      client: "Guest Client",
      date: "Mar 08, 2026",
      due_date: "Mar 15, 2026",
      time: "1",
      tasks: [],
      credits: [],
      billing_mode: "hourly",
      tax_scope: "labor,materials_only",
      currency: "USD",
      hourly_rate: 100,
      invoice_number: 1001,
      status: "draft",
      ip_address: ip_address,
      session_id: session_id
    )
  end

  def create_category(user:, name:)
    Category.create!(
      user: user,
      name: name,
      icon: "star",
      icon_type: "premade",
      color: "#EAB308"
    )
  end

  def create_client(user:, name:)
    Client.create!(user: user, name: name)
  end
end
