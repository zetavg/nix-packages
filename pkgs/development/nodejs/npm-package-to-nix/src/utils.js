// Function to imperatively fold the array of key-value pair back to an object
// eslint-disable-next-line no-param-reassign,no-sequences
const foldKVParisToObj = a => a.reduce((newObj, [key, value]) => (newObj[key] = value, newObj), {})

// Function to map an object to an array
const mapObjToArr = (obj, mapFn) => (
  Object.keys(obj)
    .map(key => [key, obj[key]])
    .map(kv => mapFn(...kv))
)

// Function to map an object as its key-value pairs
const mapObj = (obj, mapFn, { async = false } = {}) => {
  const mappedArr = mapObjToArr(obj, mapFn)

  return (async ?
    Promise.all(mappedArr).then(foldKVParisToObj)
    :
    foldKVParisToObj(mappedArr)
  )
}

// Function to filter the values of an object
const filterObjValues = (obj, filterFn) => {
  const filteredArr = Object.keys(obj)
    .map(key => [key, obj[key]])
    .filter(([, val]) => filterFn(val))
  return foldKVParisToObj(filteredArr)
}

// Replace special characters in package names
const normalizePackageName = pkgName => (
  pkgName
    .replace(/^@/, 'at-')
    .replace('@', '-at-')
    .replace('/', '--')
)

module.exports = {
  foldKVParisToObj,
  mapObjToArr,
  mapObj,
  filterObjValues,
  normalizePackageName,
}
