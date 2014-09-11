Example = require './generators/examples/Example'

NgResource = require './generators/resources/NgResource'

Tutorial = require './generators/tutorials/Tutorial'

module.exports =
  "module": require './generators/Module'
  "example": Example
  "ng-resource": NgResource
  "tutorial": Tutorial