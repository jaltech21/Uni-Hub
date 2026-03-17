// Real-time Username Validation
document.addEventListener('DOMContentLoaded', function() {
  const usernameField = document.getElementById('username_field');
  const validationIcon = document.getElementById('username_validation_icon');
  const loadingIcon = document.getElementById('username_loading');
  const availableIcon = document.getElementById('username_available');
  const unavailableIcon = document.getElementById('username_unavailable');
  const validationMessage = document.getElementById('username_validation_message');
  const messageText = document.getElementById('username_message_text');
  
  let debounceTimeout;
  let lastCheckedUsername = '';
  
  if (!usernameField) return;
  
  function showIcon(icon) {
    [loadingIcon, availableIcon, unavailableIcon].forEach(i => i.classList.add('hidden'));
    if (icon) {
      validationIcon.classList.remove('hidden');
      icon.classList.remove('hidden');
    } else {
      validationIcon.classList.add('hidden');
    }
  }
  
  function showMessage(message, isError) {
    if (message) {
      messageText.textContent = message;
      validationMessage.classList.remove('hidden');
      validationMessage.classList.remove('text-green-600', 'text-red-600');
      validationMessage.classList.add(isError ? 'text-red-600' : 'text-green-600');
    } else {
      validationMessage.classList.add('hidden');
    }
  }
  
  function updateInputBorder(state) {
    usernameField.classList.remove('border-gray-300', 'border-green-500', 'border-red-500');
    if (state === 'valid') {
      usernameField.classList.add('border-green-500');
    } else if (state === 'invalid') {
      usernameField.classList.add('border-red-500');
    } else {
      usernameField.classList.add('border-gray-300');
    }
  }
  
  async function checkUsername(username) {
    if (username === lastCheckedUsername) return;
    lastCheckedUsername = username;
    
    // Don't check if empty
    if (!username || username.trim() === '') {
      showIcon(null);
      showMessage('', false);
      updateInputBorder('neutral');
      return;
    }
    
    // Show loading state
    showIcon(loadingIcon);
    showMessage('Checking availability...', false);
    updateInputBorder('neutral');
    
    try {
      const response = await fetch(`/check_username?username=${encodeURIComponent(username)}`);
      const data = await response.json();
      
      if (data.available) {
        showIcon(availableIcon);
        showMessage(data.message, false);
        updateInputBorder('valid');
      } else {
        showIcon(unavailableIcon);
        showMessage(data.message, true);
        updateInputBorder('invalid');
      }
    } catch (error) {
      console.error('Error checking username:', error);
      showIcon(null);
      showMessage('Error checking username availability', true);
      updateInputBorder('neutral');
    }
  }
  
  usernameField.addEventListener('input', function(e) {
    const username = e.target.value.trim();
    
    // Clear previous timeout
    clearTimeout(debounceTimeout);
    
    // Debounce for 500ms
    debounceTimeout = setTimeout(() => {
      checkUsername(username);
    }, 500);
  });
  
  // Also check on blur
  usernameField.addEventListener('blur', function(e) {
    const username = e.target.value.trim();
    if (username && username !== lastCheckedUsername) {
      clearTimeout(debounceTimeout);
      checkUsername(username);
    }
  });
});
