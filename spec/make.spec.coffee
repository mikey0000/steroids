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
      args: ["update"]
      timeout: 600000

    runs =>
      session = @testHelper.runInProject
        args: ["make"]

      runs ->
        expect( fs.existsSync(distPath) ).toBe(true)
