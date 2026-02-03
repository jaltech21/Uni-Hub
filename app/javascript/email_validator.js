// Real-time Email Validation
document.addEventListener('DOMContentLoaded', function() {
  const emailField = document.getElementById('email_field');
  const validationIcon = document.getElementById('email_validation_icon');
  const loadingIcon = document.getElementById('email_loading');
  const availableIcon = document.getElementById('email_available');
  const unavailableIcon = document.getElementById('email_unavailable');
  const validationMessage = document.getElementById('email_validation_message');
  const messageText = document.getElementById('email_message_text');
  
  let debounceTimeout;
  let lastCheckedEmail = '';
  
  if (!emailField) return;
  
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
    emailField.classList.remove('border-gray-300', 'border-green-500', 'border-red-500');
    if (state === 'valid') {
      emailField.classList.add('border-green-500');
    } else if (state === 'invalid') {
      emailField.classList.add('border-red-500');
    } else {
      emailField.classList.add('border-gray-300');
    }
  }
  
  async function checkEmail(email) {
    if (email === lastCheckedEmail) return;
    lastCheckedEmail = email;
    
    // Don't check if empty
    if (!email || email.trim() === '') {
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
      const response = await fetch(`/check_email?email=${encodeURIComponent(email)}`);
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
      console.error('Error checking email:', error);
      showIcon(null);
      showMessage('Error checking email availability', true);
      updateInputBorder('neutral');
    }
  }
  
  emailField.addEventListener('input', function(e) {
    const email = e.target.value.trim();
    
    // Clear previous timeout
    clearTimeout(debounceTimeout);
    
    // Debounce for 500ms
    debounceTimeout = setTimeout(() => {
      checkEmail(email);
    }, 500);
  });
  
  // Also check on blur
  emailField.addEventListener('blur', function(e) {
    const email = e.target.value.trim();
    if (email && email !== lastCheckedEmail) {
      clearTimeout(debounceTimeout);
      checkEmail(email);
    }
  });
});
