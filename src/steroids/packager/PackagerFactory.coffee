CordovaPackager = require "./CordovaPackager"
SteroidsPackager = require "./SteroidsPackager"

module.exports = class PackagerFactory

  @create: ->
    switch steroidsCli.projectType
      when "cordova"
        new CordovaPackager
      else
        new SteroidsPackager
