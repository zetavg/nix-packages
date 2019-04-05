const path = require('path')
const pacote = require('pacote')
const utils = require('./utils')

const generalizeBinFieldInPackage = binField =>
  (typeof bin === 'string') ?
  { [path.basename(bin, '.js')]: bin } :
  binField

const asyncPopulatePkgData = async (name, data) => {
  const metadata = await pacote.manifest(`${name}@${data.version}`, { 'full-metadata': true })

  const populatedData = {
    ...data,
    scripts: metadata.scripts,
    bin: generalizeBinFieldInPackage(metadata.bin),
  }

  if (data.dependencies) {
    // eslint-disable-next-line no-use-before-define
    populatedData.dependencies = await asyncPopulateDataForDependencies(data.dependencies)
  }

  return populatedData
}

const asyncPopulateDataForDependencies = dependencies =>
  utils.mapObj(dependencies, async (name, data) => [
    name,
    await asyncPopulatePkgData(name, data),
  ], { async: true })

module.exports = {
  generalizeBinFieldInPackage,
  asyncPopulatePkgData,
  asyncPopulateDataForDependencies,
}
