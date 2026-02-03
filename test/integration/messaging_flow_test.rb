require 'test_helper'

class MessagingFlowTest < ActionDispatch::IntegrationTest
  def setup
    @tutor = users(:teacher)
    @student = users(:student)
    @admin = users(:admin)
  end

  test "tutor can access messages page" do
    sign_in @tutor
    get conversations_messages_path
    assert_response :success
  end

  test "student can access messages page" do
    sign_in @student
    get conversations_messages_path
    assert_response :success
  end

  test "admin can access messages page" do
    sign_in @admin
    get conversations_messages_path
    assert_response :success
  end

  test "tutor can view conversation with student" do
    sign_in @tutor
    get message_path(@student)
    assert_response :success
    assert_select 'h2', text: @student.full_name
  end

  test "tutor can send message to student" do
    sign_in @tutor
    
    assert_difference 'ChatMessage.count', 1 do
      post messages_path(user_id: @student.id, format: :json),
        params: { chat_message: { content: 'Hello student!', message_type: 'text' } },
        headers: { 'Accept' => 'application/json' }
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
    assert_equal 'Hello student!', json_response['message']['content']
  end

  test "student can send message to tutor" do
    sign_in @student
    
    assert_difference 'ChatMessage.count', 1 do
      post messages_path(user_id: @tutor.id, format: :json),
        params: { chat_message: { content: 'Hello tutor!', message_type: 'text' } },
        headers: { 'Accept' => 'application/json' }
    end
    
    assert_response :success
    json_response = JSON.parse(response.body)
    assert json_response['success']
  end

  test "message appears in conversation" do
    sign_in @tutor
    message = ChatMessage.create!(
      sender: @tutor,
      recipient: @student,
      content: 'Test message',
      message_type: 'text'
    )
    
    get message_path(@student)
    assert_response :success
    assert_select '.bg-blue-600', text: /Test message/
  end

  test "search users endpoint works" do
    sign_in @tutor
    get search_users_messages_path(q: @student.email, format: :json)
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert json_response.is_a?(Array)
    assert json_response.any? { |u| u['id'] == @student.id }
  end

  test "cannot send empty message" do
    sign_in @tutor
    
    assert_no_difference 'ChatMessage.count' do
      post messages_path(user_id: @student.id, format: :json),
        params: { chat_message: { content: '', message_type: 'text' } },
        headers: { 'Accept' => 'application/json' }
    end
    
    assert_response :unprocessable_entity
  end

  test "messages are marked as read when viewing conversation" do
    message = ChatMessage.create!(
      sender: @student,
      recipient: @tutor,
      content: 'Unread message',
      message_type: 'text',
      read_at: nil
    )
    
    sign_in @tutor
    get message_path(@student)
    
    message.reload
    assert_not_nil message.read_at
  end

  test "conversation shows both sent and received messages" do
    sent_message = ChatMessage.create!(
      sender: @tutor,
      recipient: @student,
      content: 'From tutor',
      message_type: 'text'
    )
    
    received_message = ChatMessage.create!(
      sender: @student,
      recipient: @tutor,
      content: 'From student',
      message_type: 'text'
    )
    
    sign_in @tutor
    get message_path(@student)
    
    assert_response :success
    assert_select 'p', text: /From tutor/
    assert_select 'p', text: /From student/
  end

  test "user cannot view other private conversations" do
    # Create conversation between student and admin
    message = ChatMessage.create!(
      sender: @student,
      recipient: @admin,
      content: 'Private message',
      message_type: 'text'
    )
    
    sign_in @tutor
    # Tutor views conversation with student
    get message_path(@student)
    
    # Should not see the private message between student and admin
    assert_response :success
    assert_select 'p', text: /Private message/, count: 0
  end

  test "tutor can delete their own message" do
    message = ChatMessage.create!(
      sender: @tutor,
      recipient: @student,
      content: 'Delete me',
      message_type: 'text'
    )
    
    sign_in @tutor
    
    assert_difference 'ChatMessage.count', -1 do
      delete message_path(message, format: :json)
    end
    
    assert_response :success
  end

  test "redirect to conversations from messages index" do
    sign_in @tutor
    get messages_path
    assert_redirected_to conversations_messages_path
  end
end
