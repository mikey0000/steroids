_ = require "lodash"

paths = require "../paths"

class SupersonicConfig

  defaults:
    copyToUserFiles: []
    hooks:
      preMake:
        cmd: null
        args: null
      postMake:
        cmd: null
        args: null

  constructor: ->
    @appConfigPath = paths.application.configs.app
    @structureConfigPath = paths.application.configs.structure

    delete require.cache[@appConfigPath] if require.cache[@appConfigPath]
    delete require.cache[@structureConfigPath] if require.cache[@structureConfigPath]

  getCurrent: ->
    appConfig = require @appConfigPath
    structureConfig =
      structure: require @structureConfigPath

    @currentConfig = _.merge appConfig, structureConfig

    @setDefaults @currentConfig

    @currentConfig

  setDefaults: ->
    @currentConfig = _.merge @currentConfig, @defaults


module.exports = SupersonicConfig
