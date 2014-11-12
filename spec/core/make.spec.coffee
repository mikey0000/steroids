TestHelper = require "../test_helper"

describe 'make', ->

  beforeEach =>
    @testHelper = new TestHelper
    @testHelper.prepare()

  it 'creates the dist', =>
    fs = require "fs"
    path = require "path"
    wrench = require "wrench"

    distPath = path.join(@testHelper.testAppPath, "dist")
    wrench.rmdirSyncRecursive(distPath, true)

    session = @testHelper.runInProject
      args: ["make"]

    runs ->
      expect( fs.existsSync(distPath) ).toBe(true)
