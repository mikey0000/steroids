PackagerBase = require "./Base"
paths = require "../paths"

module.exports = class CordovaPackager extends PackagerBase
  constructor: ->
    super
      distDir: paths.cordovaSupport.distDir
