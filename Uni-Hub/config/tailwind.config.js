const path = require('path');
const plugin = require('tailwindcss/plugin');

module.exports = {
  content: [
    './app/views/**/*.html.erb',
    './app/helpers/**/*.rb',
    './app/assets/stylesheets/**/*.css',
    './app/javascript/**/*.js',
    path.join(path.dirname(require.resolve('actiontext')), '**/*.css'),
    path.join(path.dirname(require.resolve('actiontext')), '**/*.js'),
  ],
  theme: {
    extend: {},
  },
  plugins: [],
};
