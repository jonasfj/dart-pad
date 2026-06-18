import { nodeResolve } from '@rollup/plugin-node-resolve';
import commonjs from '@rollup/plugin-commonjs';
import json from '@rollup/plugin-json';
import nodePolyfills from 'rollup-plugin-polyfill-node';
import terser from '@rollup/plugin-terser';
import typescript from '@rollup/plugin-typescript';
import { lezer } from '@lezer/generator/rollup';

const getPlugins = () => [
  lezer(),
  nodeResolve({ browser: true }),
  nodePolyfills(),
  commonjs(),
  json(),
  typescript({ target: "es2020", lib: ["es2020", "dom"], moduleResolution: "bundler" }),
  terser(), // Enable to minify
];

export default {
  input: './js/editor.ts',
  output: {
    file: './web/asset/bundle.js',
    format: 'iife',
    name: 'Editor'
  },
  plugins: getPlugins(),
};
