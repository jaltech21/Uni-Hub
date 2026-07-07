const path = require("path");
const webpack = require("webpack");
const HtmlWebpackPlugin = require("html-webpack-plugin");

module.exports = {
  mode: "development",
  entry: "./web/index.js",
  output: {
    path: path.resolve(__dirname, "dist"),
    filename: "bundle.js",
  },
  devServer: {
    port: 3000,
    hot: true,
    open: true,
    historyApiFallback: true,
  },
  module: {
    rules: [
      {
        test: /\.[jt]sx?$/,
        exclude: /node_modules/,
        use: {
          loader: "babel-loader",
          options: {
            presets: [
              "@babel/preset-env",
              ["@babel/preset-react", { runtime: "automatic" }],
              "@babel/preset-typescript",
            ],
          },
        },
      },
      {
        test: /\.css$/,
        use: ["style-loader", "css-loader", "postcss-loader"],
      },
      {
        test: /\.(png|jpg|gif|svg)$/,
        type: "asset",
      },
    ],
  },
  resolve: {
    extensions: [".web.js", ".js", ".web.ts", ".ts", ".web.tsx", ".tsx"],
    alias: {
      "@context": path.resolve(__dirname, "app/context"),
      "@screens": path.resolve(__dirname, "app/screens"),
      "@navigation": path.resolve(__dirname, "app/navigation"),
      "@components": path.resolve(__dirname, "app/components"),
      "@services": path.resolve(__dirname, "app/services"),
      "@types": path.resolve(__dirname, "app/types"),
      "@theme": path.resolve(__dirname, "app/theme"),
      "@utils": path.resolve(__dirname, "app/utils"),
      "react-native": "react-native-web",
      "react-native-keychain": path.resolve(__dirname, "web/mocks/keychain.js"),
    },
  },
  plugins: [
    new HtmlWebpackPlugin({
      template: "./web/index.html",
    }),
    new webpack.DefinePlugin({
      __DEV__: true,
      "process.env.EXPO_PUBLIC_API_URL": JSON.stringify(
        process.env.EXPO_PUBLIC_API_URL || "http://localhost:3000/api/v1"
      ),
    }),
  ],
};
