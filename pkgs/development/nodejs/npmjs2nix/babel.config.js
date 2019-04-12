module.exports = {
  presets: [
    [require('@babel/preset-env'), {
      useBuiltIns: 'usage',
      corejs: 3,
    }],
  ],
}
