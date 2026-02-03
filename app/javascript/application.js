// Configure Turbo
import "@hotwired/turbo-rails"

// Make Turbo available globally for debugging
window.Turbo = Turbo

// Import controllers
import "controllers"

// Import channels and push notifications
import "./channels"
import "./push_notifications"

// Import username and email validators
import "./username_validator"
import "./email_validator"

// Log for debugging
console.log("Application.js loaded");
console.log("Turbo available:", typeof Turbo !== 'undefined');
