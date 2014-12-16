CordovaBuildServer = require "./CordovaBuildServer"
SteroidsBuildServer = require "./SteroidsBuildServer"

module.exports = class BuildServerFactory

  @create: (options)->
    switch steroidsCli.projectType
      when "cordova"
        new CordovaBuildServer(options)
      else
        new SteroidsBuildServer(options)
