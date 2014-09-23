fs = require "fs"
xml2js = require "xml2js"

paths = require "./paths"
Config = require "./Config"

module.exports = class ConfigXmlGenerator

  constructor: ->

  writeConfigXml: ->
    config = new Config()
    config = config.getCurrent()
