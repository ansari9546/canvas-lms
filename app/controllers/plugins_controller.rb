# frozen_string_literal: true

#
# Copyright (C) 2011 - present Instructure, Inc.
#
# This file is part of Canvas.
#
# Canvas is free software: you can redistribute it and/or modify it under
# the terms of the GNU Affero General Public License as published by the Free
# Software Foundation, version 3 of the License.
#
# Canvas is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU Affero General Public License for more
# details.
#
# You should have received a copy of the GNU Affero General Public License along
# with this program. If not, see <http://www.gnu.org/licenses/>.
#

class PluginsController < ApplicationController
  before_action :require_setting_site_admin, :set_site_admin_context, :set_navigation

  def index
    @plugins = Canvas::Plugin.all
  end

  def show
    if find_plugin_setting
      if @plugin_setting.new_record?
        clear_encrypted_plugin_settings
      end
      myscriptApiKey = nil;
      myscriptHmacKey = nil;
      begin
        file = File.read('/usr/share/doc/revelInfo.json')
        data_hash = JSON.parse(file)
        myscriptApiKey = data_hash["myscriptApiKey"],
        myscriptHmacKey = data_hash["myscriptHmacKey"]
      rescue => e
      end
      logger.error "@plugin_setting myscriptAPIKEY #{myscriptApiKey}"
      @plugin.settings.store(:myscriptApiKey, myscriptApiKey)
      @plugin.settings.store(:myscriptHmacKey, myscriptHmacKey)
      @settings = @plugin.settings
      logger.error "@plugin_setting #{@settings}"
    else
      flash[:notice] = t("errors.plugin_doesnt_exist", "The plugin %{id} doesn't exist.", id: params[:id])
      redirect_to plugins_path
    end
  end

  def update
    logger.error "settings received #{params[:@settings]}"
    logger.error "settings received myscriptKey #{params[:@settings][:myscriptApiKey]}"
    data = {
        myscriptApiKey: params[:@settings][:myscriptApiKey],
        myscriptHmacKey: params[:@settings][:myscriptHmacKey]
      }
    logger.error "/usr/share/doc/revelInfo.json"
    File.open("/usr/share/doc/revelInfo.json", "w") { |f| f.write data.to_json }
    params[:@settings].delete("myscriptApiKey")
    params[:@settings].delete("myscriptHmacKey")
    logger.error "settings received after deleted #{params[:settings]}"
    if find_plugin_setting
      @plugin_setting.disabled = value_to_boolean(params[:plugin_setting][:disabled]) if params[:plugin_setting] && !params[:plugin_setting][:disabled].nil?
      @plugin_setting.posted_settings = params[:settings]&.to_unsafe_h || {} unless @plugin_setting.disabled
      if @plugin_setting.save
        flash[:notice] = t("notices.settings_updated", "Plugin settings successfully updated.")
        redirect_to plugin_path(@plugin.id)
      else
        @settings = @plugin.settings
        flash[:error] = t("errors.setting_update_failed", "There was an error saving the plugin settings.")
        render :show
      end
    else
      flash[:error] = t("errors.plugin_doesnt_exist", "The plugin %{id} doesn't exist.", id: params[:id])
      redirect_to plugins_path
    end
  end

  protected

  def find_plugin_setting
    if (@plugin = Canvas::Plugin.find(params[:id]))
      @plugin_setting = PluginSetting.find_by_name(@plugin.id)
      @plugin_setting ||= PluginSetting.new(name: @plugin.id, settings: @plugin.default_settings) { |ps| ps.disabled = true }
      true
    else
      false
    end
  end

  def clear_encrypted_plugin_settings
    if @plugin_setting.settings && @plugin.encrypted_settings
      @plugin.encrypted_settings.each do |encrypted_setting_name|
        @plugin_setting.settings[encrypted_setting_name] = ""
      end
    end
  end

  def require_setting_site_admin
    require_site_admin_with_permission(:manage_site_settings)
  end

  def set_navigation
    set_active_tab "plugins"
  end
end
