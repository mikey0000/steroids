TestHelper = require "./test_helper"

describe 'make', ->

  beforeEach =>
    @testHelper = new TestHelper
    @testHelper.prepare()

  it 'creates the dist', =>
    fs = require "fs"
    path = require "path"

    distPath = path.join(@testHelper.testAppPath, "dist")
    expect(fs.existsSync(distPath)).toBeFalsy()

    session = @testHelper.runInProject
      args: ["make"]
      debug: true

    runs ->
      console.log "wat", distPath
      expect( fs.existsSync(distPath) ).toBe(true)
