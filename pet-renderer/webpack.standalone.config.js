const path   = require('path');
const webpack = require('webpack');

module.exports = {
  entry:  './src/standalone.js',
  output: {
    filename: 'renderer.bundle.js',
    path:     path.resolve(__dirname, 'build'),
  },
  mode:   'production',

  // pixi-spine 1.x references PIXI as an undeclared global.
  // ProvidePlugin injects `var PIXI = require('pixi.js')` into every
  // module that uses PIXI, so JavaScriptCore can resolve it.
  plugins: [
    new webpack.ProvidePlugin({
      PIXI: 'pixi.js',
    }),
  ],

  // JSON as raw strings — avoids JavaScriptCore's per-expression size limits
  // that can cause silent parse failures on iOS WKWebView file:// pages.
  module: {
    rules: [
      {
        test:  /\.json$/,
        type:  'asset/source',
      },
    ],
  },

  resolve: {
    fallback: {
      path:    false,
      fs:      false,
      buffer:  false,
      process: false,
      crypto:  false,
      stream:  false,
      url:     false,
      util:    false,
      assert:  false,
      http:    false,
      https:   false,
      os:      false,
      zlib:    false,
    },
  },
};
