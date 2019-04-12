import nijs from 'nijs'
import path from 'path'
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
        const dependencydata = (
          await asyncPackageLockDependenciesToNixDependenciesAndDevDependencies(
            lockEntry.dependencies,
            packageMetadataStore,
          )
        )
        return [lockEntry, metadata, dependencydata]
      }),
  )

  const dependenciesAndDevDependencies = arrayOfLockEntryMetadataAndDependencydata
    .map(([lockEntry, metadata, { dependencies, devDependencies }]) => {
      const nixAttrs = {
        ...packageMetadataToNix(metadata),
        ...getSourceFromPackageLockDependencyEntry(lockEntry),
        dependencies,
        devDependencies,
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

export const asyncNpmPackageToNix = async (pkg, pkgLock) => {
  const packageMetadataStore = new PackageMetadataStore(
    getFlattenedDependencyNameAndVersionsFrom(pkgLock),
  )

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

  const dependenciesAttrs = await asyncPackageLockDependenciesToNixDependenciesAndDevDependencies(
    pkgLock.dependencies,
    packageMetadataStore,
  )

  const nixAttrs = {
    ...packageMetadataToNix(pkg),
    dependencyIgnoreRules,
    ...dependenciesAttrs,
  }
  cleanObjectInplace(nixAttrs)
  return nixAttrs
}

export const npmjs2nix = async (pkg, pkgLock) => {
  const nixAttrs = await asyncNpmPackageToNix(pkg, pkgLock)

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
