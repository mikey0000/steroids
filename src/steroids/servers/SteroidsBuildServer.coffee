paths = require "../paths"
BuildServerBase = require "./BuildServerBase"

module.exports = class SteroidsBuildServer extends BuildServerBase

  constructor: (options)->
    options.logDir = paths.application.logDir
    options.logFile = paths.application.logFile
    options.distDir = paths.application.distDir

    super options
