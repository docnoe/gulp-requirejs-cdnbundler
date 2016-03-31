vm = require("vm")
fs = require 'fs'
gutil = require('gulp-util')
File = gutil.File
rjs = require('requirejs')
merge = require('deeply')

# es = require('event-stream')
# Q = require('q')
# _ = require('underscore')

through = require 'through2'

getRuntimeConfig = (configFilePath) ->
  return vm.runInNewContext(fs.readFileSync(configFilePath) + ";\n require;")

# get dependencies that should not be bundled, but loadable by requirejs e.g. from a cdn
getEmptyPaths = (runtimeConfig, options) ->
  empty = {}
  if options and options.paths
    _.each options.paths, (path, dependencyName) ->
      if path == 'empty:' and runtimeConfig.paths[dependencyName]
        empty[dependencyName] = runtimeConfig.paths[dependencyName]
      return
  empty

optimizeBundle = (configFile, options, itemName, callback) ->
  # Capture the list of written modules by adding to an array on each onBuildWrite callback
  modulesList = []
  patchedOptions = options

  fullcontent = ""

  patchedOptions.onModuleBundleComplete = (data) ->
    console.log data.name, data.path, data.included
    optimizedFile = new File
      # base: "#{itemName}.js"
      cwd: "./"
      path: "./#{itemName}.js"
      contents: new Buffer fullcontent
      usedModules: modulesList
    callback optimizedFile

  patchedOptions.onBuildWrite = (moduleName, path, contents) ->
    modulesList.push moduleName
    fullcontent += contents

  patchedOptions.out = (text) ->
    return

  rjs.optimize patchedOptions


module.exports = (options) ->
  transform = (configFile, enc, callback) ->
    if configFile.isNull()
      @push configFile
      return callback()

    runtimeConfig = getRuntimeConfig configFile.path
    mergedOptions = merge(runtimeConfig, options)

    optimizeBundle configFile, mergedOptions, "main", (optimizedFile) =>
      console.log optimizedFile.usedModules
      @push optimizedFile

      callback()


    # @push new File {
    #   path: configFile.path
    #   contents: new Buffer(JSON.stringify(options))
    # }

  return through.obj transform


return


promiseToStream = (promise) ->
  stream = es.pause()
  promise.then ((result) ->
    stream.resume()
    stream.end result
    return
  ), (err) ->
    throw err
    return
  stream

streamToPromise = (stream) ->
  # Of course, this relies on the stream producing only one output. That is the case
  # for all uses in this file (wrapping rjs output, which is always one file).
  deferred = Q.defer()
  stream.pipe es.through((item) ->
    deferred.resolve item
    return
  )
  deferred.promise

pluckPromiseArray = (promiseArray, propertyName) ->
  promiseArray.map (promise) ->
    promise.then (result) ->
      result[propertyName]


module.exports = (runtimeConfig, options) ->
  # First run r.js to produce its default (non-bundle-aware) output. In the process,
  # we capture the list of modules it wrote.
  options = merge(runtimeConfig, options)
  primaryPromise = optimizeBundle(options)
  emptyPaths = getEmptyPaths(runtimeConfig, options)
  # Next, take the above list of modules, and for each configured bundle, write out
  # the bundle's .js file, excluding any modules included in the primary output. In
  # the process, capture the list of modules included in each bundle file.
  bundlePromises = _.map(options.bundles or {}, (bundleModules, bundleName) ->
    primaryPromise.then (primaryOutput) ->
      optimizeBundle {
        out: bundleName + '.js'
        baseUrl: options.baseUrl
        paths: options.paths
        include: bundleModules
        exclude: primaryOutput.modules
      }, bundleName
  )
  # Next, produce the "final" primary output by waiting for all the above to complete, then
  # concatenating the bundle config (list of modules in each bundle) to the end of the
  # primary file.
  finalPrimaryPromise = Q.all([ primaryPromise ].concat(bundlePromises)).then((allOutputs) ->
    primaryOutput = allOutputs[0]
    bundleOutputs = allOutputs.slice(1)
    bundleConfig = _.object(bundleOutputs.map((bundleOutput) ->
      [
        bundleOutput.itemName
        bundleOutput.modules
      ]
    ))
    bundleConfigCode = '\nrequire.config(' + JSON.stringify({
      bundles: bundleConfig
      paths: emptyPaths
    }, true, 2) + ');\n'
    new File(
      path: primaryOutput.file.path
      contents: new Buffer(primaryOutput.file.contents.toString() + bundleConfigCode))
  )
  # Convert the N+1 promises (N bundle files, 1 final primary file) into a single stream for gulp to await
  allFilePromises = pluckPromiseArray(bundlePromises, 'file').concat(finalPrimaryPromise)
  es.merge.apply es, allFilePromises.map(promiseToStream)
