fs = require "fs"
paths = require "./paths"
LegacyConfig = require "./LegacyConfig"
SupersonicConfig = require "./SupersonicConfig"

module.exports = class Config

  constructor: ->
    @version = if fs.existsSync(paths.application.configs.app)
      "supersonic"
    else
      "legacy"

  getCurrent: =>
    config = if @version is "supersonic"
      new SupersonicConfig()
    else
      new LegacyConfig()

    config.getCurrent()
