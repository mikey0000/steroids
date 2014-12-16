PackagerBase = require "./Base"
paths = require "../paths"

module.exports = class SteroidsPackager extends PackagerBase
  constructor: ->
    super
      distDir: paths.application.distDir
