var fs = require('fs')
var path = require('path')

var packagePath = process.argv[2]

var pkg = JSON.parse(fs.readFileSync(packagePath + '/package.json', 'utf8'))

if (typeof pkg.bin === 'object') {
  var bins = []
  for (var binName in pkg.bin) {
    var binPath = pkg.bin[binName]
    bins.push(binName + '|' + binPath)
  }
  console.log(bins.join('\n'))
} else if (typeof pkg.bin === 'string') {
  var binPath = pkg.bin
  var binName = path.basename(binPath)
  console.log(binName + '|' + binPath)
}
