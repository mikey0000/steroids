_ = require "lodash"

paths = require "./paths"

module.exports = class SupersonicConfig

  defaults:
    structure: {}
    hooks:
      preMake:
        cmd: null
        args: null
      postMake:
        cmd: null
        args: null

  constructor: ->
    configPath = paths.application.configs.app
    delete require.cache[configPath] if require.cache[configPath]
    @currentConfig = require configPath
    @setDefaults @currentConfig

  getCurrent: ->
    @currentConfig

  setDefaults: ->
    @currentConfig = _.merge @currentConfig, @defaults
