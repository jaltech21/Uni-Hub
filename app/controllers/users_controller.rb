class UsersController < ApplicationController
  skip_before_action :authenticate_user!, only: [:check_username, :check_email]
  
  # GET /check_username?username=johndoe
  def check_username
    username = params[:username].to_s.downcase.strip
    
    # Validate format
    if username.blank?
      render json: { available: false, message: 'Username is required' }
      return
    end
    
    if username.length < 3
      render json: { available: false, message: 'Username must be at least 3 characters' }
      return
    end
    
    if username.length > 20
      render json: { available: false, message: 'Username must be at most 20 characters' }
      return
    end
    
    unless username.match?(/\A[a-zA-Z0-9_]+\z/)
      render json: { available: false, message: 'Username can only contain letters, numbers, and underscores' }
      return
    end
    
    # Check if username exists (case-insensitive)
    exists = User.where('LOWER(username) = ?', username).exists?
    
    if exists
      render json: { available: false, message: 'Username is already taken' }
    else
      render json: { available: true, message: 'Username is available' }
    end
  end
  
  # GET /check_email?email=user@example.com
  def check_email
    email = params[:email].to_s.downcase.strip
    
    # Validate format
    if email.blank?
      render json: { available: false, message: 'Email is required' }
      return
    end
    
    # Basic email format validation
    unless email.match?(/\A[^@\s]+@[^@\s]+\.[^@\s]+\z/)
      render json: { available: false, message: 'Please enter a valid email address' }
      return
    end
    
    # Check if email exists (case-insensitive)
    exists = User.where('LOWER(email) = ?', email).exists?
    
    if exists
      render json: { available: false, message: 'Email is already registered' }
    else
      render json: { available: true, message: 'Email is available' }
    end
  end
end
