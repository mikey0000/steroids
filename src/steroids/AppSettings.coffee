paths = require "./paths"
Converter = require "./Converter"
fs = require "fs"

class AppSettings

  WHITELISTED_SETTING_KEYS = [
    "preloads"
    "drawers"
    "initialView"
    "tabs"
    "rootView"
  ]

  constructor: ->

  getJSON: ->
    converter = new Converter

    tempSettingsObject = converter.configToAnkaFormat()

    settingsObject = {}
    for whitelisted_keys in WHITELISTED_SETTING_KEYS
      settingsObject[whitelisted_keys] = tempSettingsObject[whitelisted_keys]

    JSON.stringify settingsObject, null, 2

  createJSONFile: ->
    settingsAsJson = @getJSON()
    fs.writeFileSync paths.application.configs.appgyverSettings, settingsAsJson

module.exports = AppSettings
