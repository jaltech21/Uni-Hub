class PersonalizationPreferencesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_personalization_preference, only: [:show, :update, :reset_theme, :apply_preset]
  
  def show
    @personalization_preference = current_user.user_personalization_preference || 
                                  current_user.build_user_personalization_preference
    
    # Provide theme options and presets
    @theme_options = UserPersonalizationPreference::THEMES
    @layout_options = UserPersonalizationPreference::LAYOUT_STYLES
    @preset_themes = get_theme_presets
    
    respond_to do |format|
      format.html
      format.json { render json: @personalization_preference }
    end
  end
  
  def update
    # Handle accessibility settings in JSONB field
    accessibility_settings = @personalization_preference.accessibility_settings || {}
    
    if params[:user_personalization_preference][:accessibility_high_contrast].present?
      accessibility_settings['high_contrast_mode'] = params[:user_personalization_preference][:accessibility_high_contrast] == '1'
    end
    
    if params[:user_personalization_preference][:accessibility_large_text].present?
      accessibility_settings['large_text'] = params[:user_personalization_preference][:accessibility_large_text] == '1'
    end
    
    if params[:user_personalization_preference][:accessibility_reduced_motion].present?
      accessibility_settings['reduced_motion'] = params[:user_personalization_preference][:accessibility_reduced_motion] == '1'
    end
    
    respond_to do |format|
      if @personalization_preference.update(personalization_params.merge(accessibility_settings: accessibility_settings))
        # Generate CSS variables for the updated theme
        css_variables = @personalization_preference.apply_theme_to_css
        
        format.html do
          flash[:notice] = 'Personalization preferences updated successfully!'
          redirect_to personalization_preferences_path
        end
        format.json do
          render json: {
            status: 'success',
            message: 'Preferences updated successfully',
            css_variables: css_variables,
            preference: @personalization_preference
          }
        end
      else
        format.html do
          flash[:alert] = 'Failed to update preferences: ' + @personalization_preference.errors.full_messages.join(', ')
          render :show
        end
        format.json do
          render json: {
            status: 'error',
            errors: @personalization_preference.errors.full_messages
          }, status: :unprocessable_entity
        end
      end
    end
  end
  
  def reset_theme
    @personalization_preference.update!(
      theme: 'light',
      layout_style: 'standard',
      color_scheme: {},
      accessibility_settings: {
        'high_contrast_mode' => false,
        'large_text' => false,
        'reduced_motion' => false
      }
    )
    
    respond_to do |format|
      format.html do
        flash[:notice] = 'Theme reset to default successfully!'
        redirect_to personalization_preferences_path
      end
      format.json do
        render json: {
          status: 'success',
          message: 'Theme reset successfully',
          css_variables: @personalization_preference.apply_theme_to_css,
          preference: @personalization_preference
        }
      end
    end
  end
  
  def apply_preset
    preset_name = params[:preset]
    preset = get_theme_presets[preset_name.to_sym]
    
    if preset
      @personalization_preference.update!(preset)
      
      respond_to do |format|
        format.html do
          flash[:notice] = "Applied #{preset_name.humanize} theme successfully!"
          redirect_to personalization_preferences_path
        end
        format.json do
          render json: {
            status: 'success',
            message: "Applied #{preset_name.humanize} theme successfully",
            css_variables: @personalization_preference.apply_theme_to_css,
            preference: @personalization_preference
          }
        end
      end
    else
      respond_to do |format|
        format.html do
          flash[:alert] = 'Invalid theme preset'
          redirect_to personalization_preferences_path
        end
        format.json do
          render json: {
            status: 'error',
            message: 'Invalid theme preset'
          }, status: :bad_request
        end
      end
    end
  end
  
  private
  
  def set_personalization_preference
    @personalization_preference = current_user.user_personalization_preference || 
                                  current_user.create_user_personalization_preference!
  end
  
  def personalization_params
    params.require(:user_personalization_preference).permit(
      :theme,
      :layout_style,
      :sidebar_collapsed
    )
  end
  
  def get_theme_presets
    {
      classic: {
        theme: 'light',
        layout_style: 'classic',
        custom_css_variables: {
          '--primary-color' => '#007bff',
          '--secondary-color' => '#6c757d',
          '--success-color' => '#28a745',
          '--border-radius' => '4px'
        }
      },
      modern_light: {
        theme: 'light',
        layout_style: 'modern',
        custom_css_variables: {
          '--primary-color' => '#6366f1',
          '--secondary-color' => '#8b5cf6',
          '--success-color' => '#10b981',
          '--border-radius' => '8px'
        }
      },
      modern_dark: {
        theme: 'dark',
        layout_style: 'modern',
        custom_css_variables: {
          '--primary-color' => '#818cf8',
          '--secondary-color' => '#a78bfa',
          '--success-color' => '#34d399',
          '--border-radius' => '8px'
        }
      },
      high_contrast: {
        theme: 'light',
        layout_style: 'classic',
        accessibility_high_contrast: true,
        accessibility_large_text: true,
        custom_css_variables: {
          '--primary-color' => '#000000',
          '--secondary-color' => '#333333',
          '--success-color' => '#006600',
          '--border-radius' => '2px'
        }
      },
      minimal: {
        theme: 'light',
        layout_style: 'minimal',
        compact_mode: true,
        custom_css_variables: {
          '--primary-color' => '#2563eb',
          '--secondary-color' => '#64748b',
          '--success-color' => '#059669',
          '--border-radius' => '6px'
        }
      },
      colorful: {
        theme: 'color',
        layout_style: 'modern',
        custom_css_variables: {
          '--primary-color' => '#f59e0b',
          '--secondary-color' => '#ef4444',
          '--success-color' => '#10b981',
          '--info-color' => '#3b82f6',
          '--warning-color' => '#f59e0b',
          '--border-radius' => '12px'
        }
      }
    }
  end
end