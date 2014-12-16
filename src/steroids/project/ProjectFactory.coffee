SteroidsProject = require "./SteroidsProject"
CordovaProject = require "./CordovaProject"

module.exports = class ProjectFactory

  @create: ->
    switch steroidsCli.projectType
      when "cordova"
        new CordovaProject()
      else
        new SteroidsProject()
