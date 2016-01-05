# gulp-requirejs-cdnbundler

A require-bundler plugin for [gulp](https://github.com/wearefractal/gulp).

Apart from normal bundling, this plugin also adds a require.config call to the final optimized script in which all paths are re-added that where removed from the build by using "empty:" during optimization.

Thanks to [@SteveSanderson](https://github.com/SteveSanderson) for the original gulp-requirejs-bundler and all his other great work!

## Usage

First, install `gulp-requirejs-cdnbundler` as a development dependency:

```shell
npm install --save-dev gulp-requirejs-cdnbundler
```

Then, add it to your `gulpfile.js` (example):

```javascript
var require-bundler = require("gulp-requirejs-cdnbundler");

gulp.task("requirejs", function() {
    var requireJsOptimizerConfig, requireJsRuntimeConfig;
    // get the "normal" config that is used during development. You can also just use some JS object like
	// {
	//     paths: {
	//         foo: "path/to/foo"
	//     },
	//     shim: {
	//         someShimedModule: {
	//             deps: ["foo"]
	//         }
	//     }
	// }
    requireJsRuntimeConfig = vm.runInNewContext(fs.readFileSync("src/app/require.config.js") + "; require;");

    // config that extends or overwrites the original config
    requireJsOptimizerConfig = {
      out: "scripts.js",
      baseUrl: "./src",
      name: "app/startup",
      paths: {
        requireLib: "bower_modules/requirejs/require",
        socketio: "empty:"
      },
      include: ["requireLib", "some/component"],
      insertRequire: ["app/startup"],
      bundles: {},
      optimize: "none"
    };

	// call/return rjs with the two configurations.
    return rjs(requireJsRuntimeConfig, requireJsOptimizerConfig)
    .pipe(gulp.dest("./dist/"));
  });
```

## API

### require-bundler(requireJsRuntimeConfig, requireJsOptimizerConfig)

Takes two arguments:
- the requirejs config
- the r.js optimizer config

See [requirejs config docs](http://requirejs.org/docs/api.html#config) and [requirejs optimization docs](http://requirejs.org/docs/optimization.html) for possible options.

## License

[MIT License](http://en.wikipedia.org/wiki/MIT_License)
