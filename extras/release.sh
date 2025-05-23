#!/usr/bin/env bash

version="$1"

[ "${version}" ] || {
   echo "Usage: $0 <version>"
   exit 1
}

linux_folder=tl-${version}-linux-x86_64
linux_pkg=${linux_folder}.tar.gz
windows_folder=tl-${version}-windows-x86_64
windows_pkg=${windows_folder}.zip

grep -q "# ${version}$" CHANGELOG.md || {
   echo "Please update the CHANGELOG.md for the release."
   exit 1
}

git stash

git checkout .

sed -i 's/^local VERSION = .*/local VERSION = "'${version}'"/' tl.tl
sed -i 's/^local VERSION = .*/local VERSION = "'${version}'"/' tl.lua

git status --porcelain tl.tl | grep -q " M " || {
   echo "Failed to update the version number in tl.tl."
   exit 1
}

git status --porcelain tl.lua | grep -q " M " || {
   echo "Failed to update the version number in tl.lua."
   exit 1
}

git commit tl.tl tl.lua -m "Release ${version}" || {
   echo "Failed to create the release commit."
   exit 1
}

git push || {
   echo "Failed to push the release commit."

   # Undo release commit
   git reset HEAD^ &> /dev/null
   git checkout . &> /dev/null
   exit 1
}

git tag v${version}

git push origin v${version} || {
   echo "Failed to push the release tag."
   exit 1
}

[ $(ls tl-dev-*.rockspec | wc -l) = 1 ] || {
   echo "Multiple dev rockspecs fonud."
   exit 1
}

luarocks new_version tl-dev-*.rockspec "${version}" --tag="v${version}" || {
   echo "Failed to create the new rockspec."
   exit 1
}

api_key=
[ "$LUAROCKS_API_KEY" ] && {
   api_key="--temp-key $LUAROCKS_API_KEY"
}

./luarocks upload $api_key tl-${version}-1.rockspec || {
   echo "Failed to upload the new rockspec."
   exit 1
}

sed -i 's/^local VERSION = .*/local VERSION = "'${version}'+dev"/' tl.tl
sed -i 's/^local VERSION = .*/local VERSION = "'${version}'+dev"/' tl.lua

git status --porcelain tl.tl | grep -q " M " || {
   echo "Failed to update the version number in tl.tl."
   exit 1
}

git status --porcelain tl.lua | grep -q " M " || {
   echo "Failed to update the version number in tl.lua."
   exit 1
}

git commit tl.tl tl.lua -m "Update version_string"

git push || {
   echo "Failed to push the post-release commit."
   exit 1
}

cat <<EOF > _binary/tlconfig.lua
return {
   source_dir = "src",
   build_dir = "build",
}
EOF

extras/binary.sh || {
   echo "Failed building Linux binary."
   exit 1
}

rm -rf $linux_folder
mkdir $linux_folder
cp README.md CHANGELOG.md LICENSE _binary/tlconfig.lua $linux_folder
cp -a docs/ $linux_folder
mkdir $linux_folder/src
cp tl.tl $linux_folder/src
mkdir $linux_folder/build
cp tl.lua $linux_folder/build
cp _binary/build/tl $linux_folder
tar czvpf $linux_pkg $linux_folder

extras/binary.sh --windows || {
   echo "Failed building Windows binary."
   exit 1
}

rm -rf $windows_folder
mkdir $windows_folder
cp README.md CHANGELOG.md LICENSE _binary/tlconfig.lua $windows_folder
cp -a docs/ $windows_folder
mkdir $windows_folder/src
cp tl.tl $windows_folder/src
mkdir $windows_folder/build
cp tl.lua $windows_folder/build
cp _binary/build/tl.exe $windows_folder
zip -r $windows_pkg $windows_folder

vtag=${version//./}

cat <<EOF > _binary/release.txt
Teal $version

* [What's New in Teal $version](https://github.com/teal-language/tl/blob/v$version/CHANGELOG.md#$vtag)

EOF

if which hub &>/dev/null
then
   hub release create -F _binary/release.txt -a $linux_pkg -a $windows_pkg v$version
elif which gh &>/dev/null
   gh release create v$version -F _binary/release.txt $linux_pkg $windows_pkg
else
   exit "No GitHub release tool available"
   exit 1
fi

echo "*** tl ${version} is now released! ***"
exit 0
