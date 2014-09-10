paths = require "./paths"

env = require("yeoman-generator")()
steroidsGenerator = require "generator-steroids"

q = require "q"

class ProjectCreator

  constructor: ->

  generate: (targetDirectory) ->

    deferred = q.defer()

    env.register paths.steroidsGenerator
    env.run "steroids:app", {"skip-install": false}, deferred.resolve

    return deferred.promise

module.exports = ProjectCreator
