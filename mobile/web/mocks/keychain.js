// Mock for react-native-keychain on web
export async function setGenericPassword(username, password, options) {
  localStorage.setItem(`keychain_${options?.service || 'default'}`, JSON.stringify({ username, password }));
  return { username, password };
}

export async function getGenericPassword(options) {
  const data = localStorage.getItem(`keychain_${options?.service || 'default'}`);
  return data ? JSON.parse(data) : false;
}

export async function resetGenericPassword(options) {
  localStorage.removeItem(`keychain_${options?.service || 'default'}`);
  return true;
}

export default {
  setGenericPassword,
  getGenericPassword,
  resetGenericPassword,
};
