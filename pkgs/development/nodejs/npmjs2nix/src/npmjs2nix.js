import nijs from 'nijs'
import path from 'path'
import shell from 'shelljs'
import crypto from 'crypto'
import {
  PackageMetadataStore,
  getVersionType,
  getFlattenedDependencyNameAndVersionsFrom,
} from './npm-utils'

export const cleanObjectInplace = (obj) => {
  Object.keys(obj).forEach((key) => {
    const value = obj[key]
    if (
      value === undefined
      || value === null
      || value === false
      || (typeof value === 'object' && Object.keys(value).length === 0)
    ) {
      delete obj[key]
    }
  })
  return obj
}

export const generalizeBinFieldOfPackageMetadata = (binField) => {
  const typeOfBinField = typeof binField

  switch (typeOfBinField) {
    case 'undefined':
      return undefined
    case 'string':
      return { [path.basename(binField, '.js')]: binField }
    case 'object':
      return binField
    default:
      throw new Error(`Unrecognized bin field type: ${typeOfBinField} of ${binField}`)
  }
}

export const normalizePackageName = packageName => (
  packageName
    .replace(/^@/, 'at-')
    .replace('@', '-at-')
    .replace('/', '-')
)

export const hasInstallationHooks = (packageMetadata) => {
  // TODO: Because "scripts.install" defaults to "node-gyp rebuild" if there's a
  // binding.gyp, packages that uses this default will not be considered having
  // installation hooks by this function for now. We'll probably need to check
  // for that too.
  if (typeof packageMetadata.scripts === 'object') {
    if (
      packageMetadata.scripts.preinstall
      || packageMetadata.scripts.install
      || packageMetadata.scripts.postinstall
    ) {
      return true
    }
  }

  return false
}

export const hasPrepareHooks = (packageMetadata) => {
  if (typeof packageMetadata.scripts === 'object') {
    if (
      packageMetadata.scripts.prepare
      || packageMetadata.scripts.prepack
    ) {
      return true
    }
  }

  return false
}

export const packageMetadataToNix = (packageMetadata) => {
  const {
    name,
    version,
    bin,
  } = packageMetadata

  const nixAttrs = {
    name: normalizePackageName(name),
    packageName: name,
    version,
    bin: generalizeBinFieldOfPackageMetadata(bin),
    hasPrepareHooks: hasPrepareHooks(packageMetadata),
    hasInstallationHooks: hasInstallationHooks(packageMetadata),
  }

  cleanObjectInplace(nixAttrs)

  return nixAttrs
}

export const getSourceFromPackageLockDependencyEntry = (dependencyEntry) => {
  const versionType = getVersionType(dependencyEntry.version)
  switch (versionType) {
    case 'semver': {
      const [, hashType, hash] = dependencyEntry.integrity.match(/^([^-]+)-(.+)$/)
      return {
        tarball: {
          url: dependencyEntry.resolved,
          [hashType]: hash,
        },
      }
    }
    default:
      throw new Error(`Version type ${versionType} is not supported yet`)
  }
}

export const asyncPackageLockDependenciesToNixDependenciesAndDevDependencies = async (
  dependencies,
  packageMetadataStore,
) => {
  if (!dependencies) {
    return {}
  }

  const arrayOfLockEntryMetadataAndDependencydata = await Promise.all(
    Object.keys(dependencies)
      .map(key => [key, dependencies[key]])
      .filter(([, lockEntry]) => !lockEntry.bundled)
      .map(async ([name, lockEntry]) => {
        const metadata = (
          await packageMetadataStore.asyncGet(name, lockEntry.version)
        )
        const privateDependencydata = (
          await asyncPackageLockDependenciesToNixDependenciesAndDevDependencies(
            lockEntry.dependencies,
            packageMetadataStore,
          )
        )

        const nixMetadata = {
          ...packageMetadataToNix(metadata),
          ...getSourceFromPackageLockDependencyEntry(lockEntry),
        }
        // We need to get the full dependencies and devDependencies for packages
        // that might need to "build" or "install"
        if (
          // not from a tarball and has prepare hooks, need to "build"
          (!nixMetadata.tarball && nixMetadata.hasPrepareHooks)
        ) {
          const miniumalizedMetadata = {
            name: metadata.name,
            description: '...',
            repository: '...',
            license: '...',
            dependencies: metadata.dependencies,
            devDependencies: metadata.devDependencies,
          }
          cleanObjectInplace(miniumalizedMetadata)
          if (miniumalizedMetadata.dependencies || miniumalizedMetadata.devDependencies) {
            const { dependencies, devDependencies } = await asyncNpmPackageToNix(miniumalizedMetadata)
            const dependencydata = { dependencies, devDependencies }
            return [lockEntry, nixMetadata, privateDependencydata, dependencydata]
          }
        }
        if (
          // has installation hooks, need to "install"
          nixMetadata.hasInstallationHooks
        ) {
          const miniumalizedMetadata = {
            name: metadata.name,
            description: '...',
            repository: '...',
            license: '...',
            dependencies: metadata.dependencies,
          }
          cleanObjectInplace(miniumalizedMetadata)
          if (miniumalizedMetadata.dependencies) {
            const { dependencies, devDependencies } = await asyncNpmPackageToNix(miniumalizedMetadata)
            const dependencydata = { dependencies, devDependencies }
            return [lockEntry, nixMetadata, privateDependencydata, dependencydata]
          }
        }

        return [lockEntry, nixMetadata, privateDependencydata, {}]
      }),
  )

  const dependenciesAndDevDependencies = arrayOfLockEntryMetadataAndDependencydata
    .map(([lockEntry, nixMetadata, privateDependencydata, dependencydata]) => {
      const nixAttrs = {
        ...nixMetadata,
        privateDependencies: privateDependencydata.dependencies,
        privateDevDependencies: privateDependencydata.devDependencies,
        dependencies: dependencydata.dependencies,
        devDependencies: dependencydata.devDependencies,
      }

      cleanObjectInplace(nixAttrs)
      return [lockEntry.dev, nixAttrs.name, nixAttrs]
    })
    .reduce((obj, [isDev, name, attrs]) => {
      if (isDev) {
        obj.devDependencies[name] = attrs
      } else {
        obj.dependencies[name] = attrs
      }
      return obj
    }, {
      dependencies: {},
      devDependencies: {},
    })

  cleanObjectInplace(dependenciesAndDevDependencies)
  return dependenciesAndDevDependencies
}

export const asyncNpmPackageToNix = async (pkg, pkgLock, tmpDir = shell.tempdir(), { silent = false } = {}) => {
  if (!pkgLock) {
    if (!silent) console.error(`Getting package-lock for ${pkg.name}...`)
    const tmpD = `${tmpDir}/npmjs2nix-${crypto.randomBytes(20).toString('hex')}`
    const pwd = shell.pwd()
    if (!silent) console.error(`Temporary dir is: ${tmpD}`)
    shell.mkdir('-p', tmpD)
    shell.echo(JSON.stringify(pkg)).to(`${tmpD}/package.json`)
    shell.cd(tmpD)
    shell.exec('npm install --package-lock-only')
    if (!silent) console.error(`npm install for ${pkg.name} done`)
    pkgLock = require(`${tmpD}/package-lock.json`)
    if (!silent) console.error(`got package-lock for ${pkg.name}`)
    shell.cd(pwd)
  }

  const packageMetadataStore = new PackageMetadataStore(
    getFlattenedDependencyNameAndVersionsFrom(pkgLock),
  )

  const nixMetadata = packageMetadataToNix(pkg)

  if (pkg.scripts && pkg.scripts.start) {
    nixMetadata.startScript = pkg.scripts.start
    const [,, startupFile] = nixMetadata.startScript.match(/node ['"]?(\.\/)?([._\-+a-zA-Z0-9/\\]+)['"]?/)
    if (startupFile) nixMetadata.startupFile = startupFile
  }

  if (typeof pkg.publicRoot === 'string') {
    const [,, pr] = pkg.publicRoot.match(/(\.\/)?([._\-+a-zA-Z0-9/\\]+)/)
    if (pr) nixMetadata.publicRoot = pr
  }

  let dependencyIgnoreRules = null
  if (pkg.nixDependencyIgnoreRules) {
    const rules = pkg.nixDependencyIgnoreRules
    dependencyIgnoreRules = Object.keys(rules)
      .map(key => [key, rules[key]])
      .map(([name, expr]) => [name, new nijs.NixExpression(expr)])
      .reduce((
        (obj, [key, value]) => (obj[key] = value, obj)
      ), {})
  }

  let dependencyBuildInputs = null
  if (pkg.nixDependencyBuildInputs) {
    const rules = pkg.nixDependencyBuildInputs
    dependencyBuildInputs = Object.keys(rules)
      .map(key => [key, rules[key]])
      .map(([name, expr]) => [name, new nijs.NixExpression(expr)])
      .reduce((
        (obj, [key, value]) => (obj[key] = value, obj)
      ), {})
  }

  const dependenciesAttrs = await asyncPackageLockDependenciesToNixDependenciesAndDevDependencies(
    pkgLock.dependencies,
    packageMetadataStore,
  )

  const nixAttrs = {
    ...nixMetadata,
    dependencyBuildInputs,
    dependencyIgnoreRules,
    ...dependenciesAttrs,
  }
  cleanObjectInplace(nixAttrs)
  return nixAttrs
}

export const npmjs2nix = async (pkg, pkgLock, tmpDir = shell.tempdir()) => {
  const nixAttrs = await asyncNpmPackageToNix(pkg, pkgLock, tmpDir)

  return nijs.jsToNix(new nijs.NixFunction({
    argSpec: [' src ? null', 'srcs ? null '],
    body: {
      src: new nijs.NixExpression('src'),
      srcs: new nijs.NixExpression('srcs'),
      ...nixAttrs,
    },
  }), true) + '\n'
}

export default npmjs2nix
