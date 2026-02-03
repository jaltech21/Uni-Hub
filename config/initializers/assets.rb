# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# We use importmap for JavaScript, not Sprockets
# Only CSS files are precompiled through Sprockets
# Tell Rails to check for assets before raising errors
Rails.application.config.assets.unknown_asset_fallback = false
Rails.application.config.assets.precompile += %w( actiontext.css )

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
