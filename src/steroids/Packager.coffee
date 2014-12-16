Zip = require "./fs/zip"
paths = require "./paths"
fs = require "fs"

module.exports = class Packager
  constructor: (options={})->
    distDir = if options.cordova
      paths.cordovaSupport.distDir
    else
      paths.application.distDir

    @zip = new Zip distDir, paths.temporaryZip

  create: ->
    unless process.platform is "win32"
      try
        fd = fs.openSync(paths.temporaryZip, "w")
      catch err
        console.log err.message
        console.log "Ensure that #{paths.temporaryZip} is writable"
        process.exit 1

    @zipDistPath()

  zipDistPath: ->
    @zip.create (timestamp) =>
      @latestZipTimestamp = timestamp
