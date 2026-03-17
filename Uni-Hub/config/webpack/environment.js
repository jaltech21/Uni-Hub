const { environment } = require('@rails/webpacker')
const babelLoader = environment.loaders.get('babel')

babelLoader.test = /\.js$/
delete babelLoader.exclude

// Forcefully override the `node` option to remove unsupported properties
environment.config.merge({
  node: false // Disable node polyfills entirely
})

module.exports = environment
