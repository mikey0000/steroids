TestHelper = require "../test_helper"

describe 'packager', ->

  beforeEach =>
    @testHelper = new TestHelper
    @testHelper.prepare()

  describe 'zip', =>

    it 'should be created', =>
      runs =>
        @testHelper.runInProject
          args: ["package"]

      runs =>
        Paths = require "../../src/steroids/paths"
        fs = require "fs"

        expect(fs.existsSync Paths.temporaryZip).toBe true
