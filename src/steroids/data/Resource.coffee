configApiBaseUrl = 'https://config-api.appgyver.com'

class Resource
  @ResourceError: class ResourceError extends steroidsCli.SteroidsError
  @CloudReadError: class CloudReadError extends ResourceError
  @CloudWriteError: class CloudWriteError extends ResourceError

  @fromCloudObject: (obj)=>
    steroidsCli.debug "RESOURCE", "Constructing a new resource from object: #{JSON.stringify(obj)}"
    resource = new Resource()
    resource.fromCloudObject(obj)
    return resource

  constructor: (@options={})->

  getFieldNamesSync: ()=>
    steroidsCli.debug "RESOURCE", "Getting field names from columns: #{JSON.stringify(@columns)}"

    return [] if @columns == null

    result = []
    for column in @columns
      result.push column.name

    steroidsCli.debug "RESOURCE", "Got field names from columns: #{JSON.stringify(result)}"
    return result

  fromCloudObject: (obj)=>
    steroidsCli.debug "RESOURCE", "Updating attributes for resource from object: #{JSON.stringify(obj)}"
    @uid = obj.uid
    @serviceProviderUid = obj.serviceProviderUid
    @name = obj.name
    @path = obj.path
    @columns = obj.columns
    @headers = obj.headers
    @actions = obj.actions
    @identifierKey = obj.identifierKey


module.exports = Resource
