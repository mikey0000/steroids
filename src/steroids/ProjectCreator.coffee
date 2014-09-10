steroidsGenerator = require "generator-steroids"

q = require "q"

class ProjectCreator

  constructor: ->

  generate: (targetDirectory) ->

    deferred = q.defer()

    steroidsGenerator.app({
      skipInstall: false
      projectName: targetDirectory
    }, deferred.resolve)

    return deferred.promise

module.exports = ProjectCreator
