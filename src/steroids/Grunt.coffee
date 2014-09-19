paths = require "./paths"
grunt = require "grunt"

class Grunt
  constructor: ()->

  run: (options = {}, done = ->) ->

    grunt.loadTasks paths.application.configs.grunt

    gruntOptions = {}
    gruntTasks = options.tasks || ["default"]

    grunt.tasks gruntTasks, gruntOptions, done

module.exports = Grunt
