import pacote from 'pacote'

export const getVersionType = (versionString) => {
  if (versionString.match(/^git\+/)) {
    return 'git'
  }

  if (versionString.match(/^file:/)) {
    return 'file'
  }

  return 'semver'
}

export const asyncGetPackageMetadata = async (name, version) => {
  // TODO: Handle git and file versions
  const metadata = await pacote.manifest(`${name}@${version}`, { 'full-metadata': true })
  return metadata
}

export class PackageMetadataStore {
  constructor(arrayOfTuplesOfNameAndVersion) {
    this.store = arrayOfTuplesOfNameAndVersion
      .map(([name, version]) => ([
        `${name}@${version}`,
        asyncGetPackageMetadata(name, version),
      ]))
      .reduce((
        (obj, [key, promise]) => (obj[key] = promise, obj)
      ), {})
  }

  asyncGet(name, version) {
    const key = `${name}@${version}`
    return this.store[key]
  }
}

export const getFlattenedDependencyNameAndVersionsFrom = (obj) => {
  const { dependencies } = obj
  if (dependencies) {
    return Object.keys(dependencies)
      .map(key => [key, dependencies[key]])
      .filter(([, data]) => (!data.bundled))
      .map(([name, data]) => {
        const privateDependencyNameAndVersions = getFlattenedDependencyNameAndVersionsFrom(data)
        const { version } = data
        return [[name, version]].concat(privateDependencyNameAndVersions)
      })
      .flat()
  }

  return []
}
