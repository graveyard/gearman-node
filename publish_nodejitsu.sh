#set -eu
git rev-parse --verify master
if [ $? != 0 ]
then
  echo "Will not publish to nodejitsu on non-master branch!"
  exit
fi

npm cache clean
npm install json
cp package.json package.json.bkp

npm config set registry https://clever.registry.nodejitsu.com/
npm config set strict-ssl true
npm config set always-auth true

auth=`echo -n ${npm_drone_password} | base64`
npm config set //clever.registry.nodejitsu.com/:_password "${auth}"
npm config set //clever.registry.nodejitsu.com/:username "${npm_drone_username}"
npm config set //clever.registry.nodejitsu.com/:email "${npm_drone_email}"
npm config set //clever.registry.nodejitsu.com/:always-auth true

#echo "getting name"
name=`node node_modules/json/lib/json.js -f package.json name`
#echo "got ${name}, updating name, publishing package"
if [[ $name == "@clever/"* ]]
then
  package_name=${name#$"@clever/"}
  #echo "setting package name to ${package_name}"
  node node_modules/json/lib/json.js -I -f package.json -e "this.name='${package_name}'"
fi
#echo "setting registry"
node node_modules/json/lib/json.js -I -f package.json -e "this.publishConfig={registry:'https://clever.registry.nodejitsu.com'}"
#echo "publishing"
npm publish

publish_exit_status=$?
mv package.json.bkp package.json
# remove npmrc so future npm build actions won't conflict with these credentials
rm `npm config get userconfig`
npm uninstall json

if [ $publish_exit_status != 0 ]
then
  exit $publish_exit_status
fi
