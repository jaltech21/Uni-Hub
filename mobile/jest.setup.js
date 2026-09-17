jest.mock("@react-native-async-storage/async-storage", () =>
  require("@react-native-async-storage/async-storage/jest/async-storage-mock")
);

// react-native-keychain has no native bindings under Jest; keep an
// in-memory store so api/auth services behave like on a real device.
jest.mock("react-native-keychain", () => {
  const store = new Map();
  return {
    getGenericPassword: jest.fn(async (options) => {
      const key = (options && options.service) || "default";
      return store.get(key) || false;
    }),
    setGenericPassword: jest.fn(async (username, password, options) => {
      const key = (options && options.service) || "default";
      store.set(key, password);
      return { username, password };
    }),
    resetGenericPassword: jest.fn(async (options) => {
      const key = (options && options.service) || "default";
      store.delete(key);
      return true;
    }),
  };
});
