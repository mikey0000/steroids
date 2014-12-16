Project = require "./Project"

class CordovaProject extends Project

  constructor: ->
    super()

  makeOnly: (options={}) =>
    steroidsCli.debug "Making dist/ for Cordova project..."
    @copyCordovaFiles()
    options.onSuccess?.call()

  copyCordovaFiles: ->
    fse = require "fs-extra"
    paths = require "../paths"

    fse.removeSync paths.cordovaSupport.distDir
    fse.ensureDirSync paths.cordovaSupport.distDir
    fse.copySync paths.application.wwwDir, paths.cordovaSupport.distDir
    fse.copySync paths.cordovaSupport.configXml, paths.cordovaSupport.distConfigXml

module.exports = CordovaProject
