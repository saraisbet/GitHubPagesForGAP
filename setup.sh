#!/usr/bin/env bash
#
# Run this script from within the root directory of the git clone of
# your package in order to create a gh-pages subdirectory, containing a
# checkout of your gh-pages branch. If no gh-pages branch exists, it
# also creates one.
#
# Copyright (c) 2018-2019 Max Horn
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public
# License along with this program; if not, write to the Free
# Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
# Boston, MA 02110-1301, USA.
#

set -e

######################################################################
#
# Various little helper functions


# print notices in green
notice() {
    printf '\033[32m%s\033[0m\n' "$*"
}

# print warnings in yellow
warning() {
    printf '\033[33mWARNING: %s\033[0m\n' "$*"
}

# print error in red and exit
error() {
    printf '\033[31mERROR: %s\033[0m\n' "$*"
    exit 1
}

######################################################################

# error early on if there already is a gh-pages dir
[[ -d gh-pages ]] && error "You already have a gh-pages directory"

# TODO: make it configurable which remote is used (default: origin)
remote=origin

# TODO: make it configurable how/which gap is used
GAP=${GAP:-gap}

# Based on the git documentation and some experiments, `git worktree add`
# in git 2.7 and newer works as desired. It is possible that 2.6 also
# did, but since I can't easily test that right now, I'll err on the
# safe
git_major=$(git  --version | sed -E 's/[^0-9]+([0-9]+).*/\1/')
git_minor=$(git  --version | sed -E 's/[^0-9]+[0-9]+\.([0-9]+).*/\1/')
if [[ $git_major -gt 2 || ($git_major -eq 2 && $git_minor -ge 7) ]]
then
    UseWorktree=Yes
else
    UseWorktree=No
fi
notice "Detected git ${git_major}.${git_minor}, using git worktree: ${UseWorktree}"

# TODO: add /gh-pages/ to .gitignore if it is not already in there

if [[ ${UseWorktree} = Yes ]]
then
    # Add a new remote pointing to the GitHubPagesForGAP repository
    git remote add -f gh-gap https://github.com/gap-system/GitHubPagesForGAP || :

    # if there is already a gh-pages branch, do nothing; otherwise, if
    # there is a ${remote}/gh-pages branch, create `gh-pages` tracking
    # the remote; otherwise, create a fresh `gh-pages` branch
    if ! git rev-parse -q --verify gh-pages
    then
        # fetch remote changes, so that we can see if there
        # is a remote gh-pages branch
        git fetch ${remote}

        if git rev-parse -q --verify ${remote}/gh-pages
        then
            # track the existing remote gh-pages branch
            git branch --track gh-pages ${remote}/gh-pages
        else
            # create a fresh gh-pages branch from the new remote
            git branch --no-track gh-pages gh-gap/gh-pages
            # ... then push it and set up tracking
            git push --set-upstream ${remote} gh-pages
        fi
    fi

    # create a new worktree and change into it
    git worktree add gh-pages gh-pages
    cd gh-pages
else
    # Create a fresh clone of your repository, and change into it
# FIXME: "git remote get-url" only was added in git 2.7
    url=$(git remote get-url origin)
    git clone ${url} gh-pages
    cd gh-pages

    # Add a new remote pointing to the GitHubPagesForGAP repository
    git remote add gh-gap https://github.com/gap-system/GitHubPagesForGAP
    git fetch gh-gap

    # Create a fresh gh-pages branch from the new remote
    git checkout -b gh-pages gh-gap/gh-pages --no-track
fi

cp -f ../PackageInfo.g ../README* .

[[ -d doc ]] && git rm -rf doc
mkdir -p doc/
cp -f ../doc/*.{css,html,js,txt} doc/ || :

[[ -d ../htm ]] && cp -r ../htm .

${GAP} update.g

git add .
git commit -m "Setup gh-pages based on GitHubPagesForGAP"
git push --set-upstream ${remote} gh-pages
