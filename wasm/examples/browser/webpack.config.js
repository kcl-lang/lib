const HtmlWebpackPlugin = require("html-webpack-plugin");
const MiniCssExtractPlugin = require("mini-css-extract-plugin");
const path = require("path");
const webpack = require("webpack");

const dist = path.resolve("./dist");
const isProduction = process.argv.some((x) => x === "--mode=production");
const hash = isProduction ? ".[contenthash]" : "";

module.exports = {
  mode: "development",
  entry: {
    main: "./src/main.ts",
  },
  target: "web",
  output: {
    path: dist,
    filename: `[name]${hash}.js`,
    clean: true,
  },
  devServer: {
    hot: true,
    port: 9000,
  },
  module: {
    rules: [
      {
        test: /\.css$/,
        use: [MiniCssExtractPlugin.loader, "css-loader"],
      },
      {
        test: /\.m?js$/,
        resourceQuery: { not: [/(raw|wasm)/] },
      },
      {
        resourceQuery: /raw/,
        type: "asset/source",
      },
      {
        resourceQuery: /wasm/,
        type: "asset/resource",
        generator: {
          filename: "wasm/[name][ext]",
        },
      },
    ],
  },
  plugins: [
    new MiniCssExtractPlugin(),
    new HtmlWebpackPlugin({
      template: path.resolve(__dirname, "./src/index.html"),
    }),
    new webpack.IgnorePlugin({
      resourceRegExp: /^(path|ws|crypto|fs|os|util|node-fetch)$/,
    }),
    // needed by @wasmer/wasi
    new webpack.ProvidePlugin({
      Buffer: ["buffer", "Buffer"],
    }),
  ],
  externals: {
    // needed by @wasmer/wasi
    "wasmer_wasi_js_bg.wasm": true,
  },
  resolve: {
    fallback: {
      // needed by @wasmer/wasi
      buffer: require.resolve("buffer/"),
    },
  },
};
