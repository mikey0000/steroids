TestHelper = require "../test_helper"

describe 'create', ->

  describe "arguments", ->

    it 'gives usage when no directory is specified', =>
      session = TestHelper.run
        args: ["create"]

      runs =>
        expect( session.code ).toBe 1
        expect( session.stdout ).toMatch("Usage: steroids create <directoryName>")

  describe 'steroids²', ->

    beforeEach =>
      @testHelper = new TestHelper
      @testHelper.prepare()

    describe "structure", =>
      path = require "path"
      fs = require "fs"

      beforeEach =>
        @testAppPath = @testHelper.testAppPath

        @readContentsSync = (basePath, fileName) ->
          fullPath = path.join(basePath, fileName)
          fs.readFileSync(fullPath).toString()

      describe "root", =>

        it "has .gitignore with dist", =>
          expect(@readContentsSync(@testAppPath, ".gitignore"))
          .toMatch(/dist/)

        it "has package.json with dependencies", =>
          expect(@readContentsSync(@testAppPath, "package.json"))
          .toMatch(/"private": true,/)

        it "has bower.json with dependencies", =>
          expect(@readContentsSync(@testAppPath, "bower.json"))
          .toMatch(/dependencies": {/)

        it "has Gruntfile.coffee with grunt.loadNpmTasks", =>
          expect(@readContentsSync(@testAppPath, "Gruntfile.coffee"))
          .toMatch(/grunt.loadNpmTasks/)

      describe "app", =>

        beforeEach =>
          @appPath = path.join @testHelper.testAppPath, "app"

          @appCommonPath = path.join @appPath, "common"
          @appCommonViewsPath = path.join @appCommonPath, "views"

          @appExamplePath = path.join @appPath, "example"
          @appExampleViewsPath = path.join @appExamplePath, "views"

        describe "common", =>

          it "has index.coffee with 'supersonic'", =>
            expect(@readContentsSync(@appCommonPath,"index.coffee"))
            .toMatch(/'supersonic'/)

        describe "example", =>

          it "has views/getting-started.html with a greeting", =>
            expect(@readContentsSync(@appExampleViewsPath,"getting-started.html"))
            .toMatch(/Awesome! This file is located at/)

      describe "config", =>

        beforeEach =>
          @configPath = path.join @testHelper.testAppPath, "config"

        it "has app.coffee with 'name: \"__testApp\"'", =>
          expect(@readContentsSync(@configPath,"app.coffee"))
          .toMatch(/name: "__testApp"/)

        it 'has structure.coffee with \'location: "example#getting-started"\'', =>
          expect(@readContentsSync(@configPath,"structure.coffee"))
          .toMatch(/location: "common#getting-started"/)
