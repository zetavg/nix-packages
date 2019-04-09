const nijs = require('nijs')
const npmTools = require('./npmTools')
const utils = require('./utils')

const isBuildNeededForPkg = (pkg) => {
  // TODO: because "scripts.install" defaults to "node-gyp rebuild" if there's a
  // binding.gyp, packages that uses this default will not have "buildNeeded" set,
  // and might not be build when it's expected to be. We'll probably need to check
  // for that too.
  if (typeof pkg.scripts === 'object') {
    if (pkg.scripts.preinstall || pkg.scripts.install || pkg.scripts.postinstall) {
      return true
    }
  }

  return false
}

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

  if (isBuildNeededForPkg(data)) {
    nixAttrs.buildNeeded = true
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
    srcMaybeNotFromNpm: true,
    bin: npmTools.generalizeBinFieldInPackage(pkg.bin),
  }

  if (pkgLock.dependencies) {
    const deps = await npmTools.asyncPopulateDataForDependencies(pkgLock.dependencies)
    const { dependencies, devDependencies } = classifyDeps(deps)

    nixAttrs.dependencies = pkgLockDepsToNix(dependencies)
    nixAttrs.devDependencies = pkgLockDepsToNix(devDependencies)
  }

  if (isBuildNeededForPkg(pkg)) {
    nixAttrs.buildNeeded = true
  }

  return nijs.jsToNix(new nijs.NixFunction({
    argSpec: ['fetchurl', 'fetchgit'],
    body: nixAttrs,
  }), true) + '\n'
}

module.exports = asyncNpmPackageToNix
