# determine the platform
# use 32bit by default
$PLATFORM = "windows_x86"
$MONGO_VERSION = "2.6.7"
$NODE_VERSION = "5.7.1"
$NPM_VERSION = "3.7.5"

# take it form the environment if exists
if (Test-Path env:PLATFORM) {
  $PLATFORM = (Get-Item env:PLATFORM).Value
}

$script_path = Split-Path -parent $MyInvocation.MyCommand.Definition
$CHECKOUT_DIR = Split-Path -parent $script_path

# extract the bundle version from the meteor bash script
$BUNDLE_VERSION = Select-String -Path ($CHECKOUT_DIR + "\meteor") -Pattern 'BUNDLE_VERSION=(\S+)'  | % { $_.Matches[0].Groups[1].Value } | Select-Object -First 1
$BUNDLE_VERSION = $BUNDLE_VERSION.Trim()

# generate-dev-bundle-xxxxxxxx shortly
# convert relative path to absolute path because not all commands know how to deal with this themselves
$DIR = Join-Path -Path $CHECKOUT_DIR -ChildPath "gdbXXX"
$BINDIR = Join-Path -Path $DIR -ChildPath "bin"
$NODE_MODULES = Join-Path -Path $BINDIR -ChildPath "node_modules"
$NPM = Join-Path -Path $BINDIR -ChildPath "npm.cmd"
$NODE = Join-Path -Path $BINDIR -ChildPath "node.exe"

Write-Host $DIR

if (Test-Path $DIR) {
  rm -recurse -force "$DIR"
}
New-Item -Type Directory $NODE_MODULES
cd $BINDIR

$webclient = New-Object System.Net.WebClient
$shell = New-Object -com shell.application

# download node
# same node on 32bit vs 64bit?
$node_link = "http://nodejs.org/dist/v${NODE_VERSION}/win-x86/node.exe"
$webclient.DownloadFile($node_link, "$DIR\bin\node.exe")

# download initial version of npm
$npm_zip = Join-Path -Path $NODE_MODULES -ChildPath "npm.zip"
$npm_link = "https://github.com/npm/npm/archive/v${NPM_VERSION}.zip"
$webclient.DownloadFile($npm_link, $npm_zip)

$zip = $shell.NameSpace($npm_zip)
foreach($item in $zip.items()) {
  $shell.Namespace("$NODE_MODULES").copyhere($item, 0x14) # 0x10 - overwrite, 0x4 - no dialog
}

rm -Force $npm_zip

# add bin to the front of the path so we can use our own node for building
$env:PATH = "${DIR}\bin;${env:PATH}"

mv "${NODE_MODULES}\npm-${NPM_VERSION}" "${NODE_MODULES}\npm"
cd "${NODE_MODULES}\npm"
#echo "{}" | Out-File package.json -Encoding ascii # otherwise it doesn't install in local dir
npm install --production

# add bin\npm3 to the front of the path so we can use npm 3 for building
#$env:PATH = "${NODE_MODULES}\npm;${env:PATH}"

# npm depends on a hardcoded file path to node-gyp, so we need this to be
# un-flattened
#cd node_modules\npm
#npm install node-gyp
#cd ..\..
cd "${BINDIR}"
cp node_modules\npm\bin\npm.cmd .

# install dev-bundle-package.json
# use short folder names
# b for build
New-Item -Type Directory -Path "${DIR}\server-lib\node_modules"
cd "$DIR\server-lib"

Invoke-Expression "$NPM config set loglevel error"
Invoke-Expression "$NODE ${CHECKOUT_DIR}\scripts\dev-bundle-server-package.js" | Out-File -FilePath package.json -Encoding ascii
Invoke-Expression "$NPM install --production"
Invoke-Expression "$NPM shrinkwrap"
cd "${DIR}"

#mkdir -Force "${DIR}\server-lib\node_modules"
#robocopy "${DIR}\b\t\node_modules" "${DIR}\server-lib\node_modules" /e /nfl /ndl

mkdir -Force "${DIR}\etc"
Move-Item "server-lib\package.json" "${DIR}\etc\"
Move-Item "server-lib\npm-shrinkwrap.json" "${DIR}\etc\"

New-Item -Type Directory -Path "${DIR}\lib\node_modules"
cd "${DIR}\lib"
Invoke-Expression "${NODE} ${CHECKOUT_DIR}\scripts\dev-bundle-tool-package.js" | Out-File -FilePath package.json -Encoding ascii
Invoke-Expression "$NPM install --production"
#robocopy "${DIR}\b\p\node_modules" "${DIR}\lib\node_modules" /e /nfl /ndl
cd "$DIR"
#rm -recurse -force "${DIR}\b"

cd "$DIR"
mkdir "$DIR\mongodb"
mkdir "$DIR\mongodb\bin"

# download Mongo
$mongo_name = "mongodb-win32-i386-${MONGO_VERSION}"
If ($PLATFORM -eq 'windows_x86_64') {
  # 64-bit would be mongodb-win32-x86_64-2008plus-${MONGO_VERSION}.zip
  $mongo_name = "mongodb-win32-x86_64-2008plus-${MONGO_VERSION}"
}
$mongo_link = "https://fastdl.mongodb.org/win32/${mongo_name}.zip"
$mongo_zip = "$DIR\mongodb\mongo.zip"

$webclient.DownloadFile($mongo_link, $mongo_zip)

$zip = $shell.NameSpace($mongo_zip)
foreach($item in $zip.items()) {
  $shell.Namespace("$DIR\mongodb").copyhere($item, 0x14) # 0x10 - overwrite, 0x4 - no dialog
}

cp "$DIR\mongodb\$mongo_name\bin\mongod.exe" $DIR\mongodb\bin
cp "$DIR\mongodb\$mongo_name\bin\mongo.exe" $DIR\mongodb\bin

rm -Recurse -Force $mongo_zip
rm -Recurse -Force "$DIR\mongodb\$mongo_name"

# Remove npm 3 before we package the dev bundle
rm -Recurse -Force "${DIR}\bin\npm3"

cd $DIR

# mark the version
echo "${BUNDLE_VERSION}" | Out-File .bundle_version.txt -Encoding ascii

cd "$DIR\.."

# rename the folder with the devbundle
mv "$DIR" "dev_bundle_${PLATFORM}_${BUNDLE_VERSION}"

7z.exe a -ttar dev_bundle.tar "dev_bundle_${PLATFORM}_${BUNDLE_VERSION}"
7z.exe a -tgzip "${CHECKOUT_DIR}\dev_bundle_${PLATFORM}_${BUNDLE_VERSION}.tar.gz" dev_bundle.tar
rm dev_bundle.tar
rm -recurse -force "dev_bundle_${PLATFORM}_${BUNDLE_VERSION}"

Write-Host "Done building Dev Bundle!"
