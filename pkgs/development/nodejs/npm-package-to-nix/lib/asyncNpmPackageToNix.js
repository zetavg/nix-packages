const nijs = require('nijs')
const npmTools = require('./npmTools')
const utils = require('./utils')

const pkgLockDepsToNix = deps => utils.mapObjToArr(deps, (name, data) => {
  const nixAttrs = {
    name: utils.normalizePackageName(name),
    packageName: name,
    version: data.version,
    bin: data.bin || undefined,
  }

  if (typeof data.resolved === 'string' && typeof data.integrity === 'string') {
    const [, hashType, hash] = data.integrity.match(/^([^-]+)-(.+)$/)

    const attrs = {
      // url: new nijs.NixURL(data.resolved),
      url: data.resolved,
      [hashType]: hash,
    }
    nixAttrs.src = new nijs.NixFunInvocation({
      funExpr: new nijs.NixExpression('fetchurl'),
      paramExpr: attrs,
    })
  } else {
    // TODO: Handle other cases
  }

  if (typeof data.scripts === 'object') {
    if (data.scripts.preinstall || data.scripts.install || data.scripts.postinstall) {
      nixAttrs.buildNeeded = true
    }
  }

  if (data.dependencies) {
    const { dependencies, devDependencies } = classifyDeps(data.dependencies)

    nixAttrs.dependencies = pkgLockDepsToNix(dependencies)
    nixAttrs.devDependencies = pkgLockDepsToNix(devDependencies)
  }

  return nixAttrs
})

const classifyDeps = (deps) => {
  const requiredDeps = utils.filterObjValues(deps, d => !d.bundled)
  const dependencies = utils.filterObjValues(requiredDeps, d => !d.dev)
  const devDependencies = utils.filterObjValues(requiredDeps, d => d.dev)
  return {
    dependencies,
    devDependencies,
  }
}

const asyncNpmPackageToNix = async (pkg, pkgLock) => {
  const nixAttrs = {
    name: utils.normalizePackageName(pkg.name),
    packageName: pkg.name,
    version: pkg.version,
    src: new nijs.NixURL('./.'),
    bin: npmTools.generalizeBinFieldInPackage(pkg.bin),
  }

  if (pkgLock.dependencies) {
    const deps = await npmTools.asyncPopulateDataForDependencies(pkgLock.dependencies)
    const { dependencies, devDependencies } = classifyDeps(deps)

    nixAttrs.dependencies = pkgLockDepsToNix(dependencies)
    nixAttrs.devDependencies = pkgLockDepsToNix(devDependencies)
  }

  if (typeof pkg.scripts === 'object') {
    if (pkg.scripts.preinstall || pkg.scripts.install || pkg.scripts.postinstall) {
      nixAttrs.buildNeeded = true
    }
  }

  return nijs.jsToNix(new nijs.NixFunction({
    argSpec: ['fetchurl', 'fetchgit'],
    body: nixAttrs,
  }), true)
}

module.exports = asyncNpmPackageToNix
