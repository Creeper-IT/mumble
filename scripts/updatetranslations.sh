#!/usr/bin/env bash
#
# Copyright 2005-2020 The Mumble Developers. All rights reserved.
# Use of this source code is governed by a BSD-style license
# that can be found in the LICENSE file at the root of the
# Mumble source tree or at <https://www.mumble.info/LICENSE>.

# Updates mumble_en.ts from source and adds a commit.
#
# The main actions this script performs:
# * lupdate to update translation strings
# * Duplicate single 'numerusform' entries in mumble_en.ts to work around #1195
# * Commit the resulting translation file
#
# Requires qt5 ; sudo apt-get install libqt5-dev
# As the QT project files are parsed, additional qt dependencies apply;
# sudo apt-get install libqt5svg5-dev

set -u
set -e
set -o pipefail

file="mumble_en.ts"
rootDir="$(dirname $(realpath $0))/.."
filePath="./src/mumble/$file"

cd "$rootDir"

# Make sure we are using  Qt5
export QT_SELECT=5
tmpfile="commitmessage.tmp"

function requireCommand
{
	local c=$1
	command -v $c >/dev/null 2>&1 || { printError "The required command $c is not available." >&2; exit 1; }
}

function checkRequirements
{
	requireCommand lupdate
	requireCommand qmake
	requireCommand perl
	requireCommand git
}

function printError
{
	echo -e "\e[1;31mERROR\e[0m: $1"
}

function fatal
{
	local msg="${1:-"Exiting because a command returned the error code $code"}"

	printError "$msg"
	exit 1
}

function main
{
	checkRequirements

	if ! [[ -f "$filePath" ]];
	then
		printError "Could not find file '$filePath'."
		exit 1
	fi

	if [[ -n $(git status --porcelain "$filePath") ]] ; then
		printError "The file $filePath has local changes."
		exit 1
	fi

	echo "TRANSLATION: Update translation files" > $tmpfile
	echo "" >> $tmpfile
	
	lupdate -no-ui-lines -disable-heuristic similartext -locations none -no-obsolete -no-recursive "./src" "./src/mumble" -ts "$filePath" \
		| tee -a $tmpfile || fatal "lupdate failed"
	echo ""

	# Duplicate single numerusform entries in mumble_en.ts to work around #1195
	perl -pi -e 's!(^\s*)(<numerusform></numerusform>)$!\1\2\2!' $filePath || (rm $tmpfile ; fatal "Workardound for #1195 failed - in-place replacement via perl.")
	

	if ! [[ -n $(git status --porcelain $filePath) ]] ; then
		echo "No translation changes. Nothing to commit."
		rm $tmpfile
		exit 0
	fi

	echo "Committing changes ..."
	git commit -F $tmpfile $filePath || (rm $tmpfile ; fatal "Failed to commit the changes")
	rm $tmpfile || printError "Failed to remove temporary file '$tmpfile'"

	echo "Probably done."
	echo
	echo "Before pushing, _manually_ check the output above as well as the commits changes."
	echo "An lupdate warning about overriding TRANSLATIONS is expected, as well as \"removal of plural forms\". Any project errors (missing qt modules) however are not, and the resulting changes must not be pushed."
}

main

