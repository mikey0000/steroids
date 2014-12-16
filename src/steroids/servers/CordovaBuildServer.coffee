paths = require "../paths"
BuildServerBase = require "./BuildServerBase"

module.exports = class CordovaBuildServer extends BuildServerBase

  constructor: (options = {})->
    options.logDir = paths.cordovaSupport.logDir
    options.logFile = paths.cordovaSupport.logFile
    options.distDir = paths.cordovaSupport.distDir

    super options
