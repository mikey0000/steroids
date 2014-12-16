Zip = require "../fs/zip"
paths = require "../paths"
fs = require "fs"

module.exports = class PackagerBase
  constructor: (options={})->
    @zip = new Zip options.distDir, paths.temporaryZip

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
    new Promise (resolve) =>
      @zip.create (timestamp) =>
        @latestZipTimestamp = timestamp
        resolve()
