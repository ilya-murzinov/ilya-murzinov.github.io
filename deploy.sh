#!/bin/bash

# Temporarily store uncommited changes
git stash

# Verify correct branch
git checkout hakyll

# Build new files
stack build
stack exec site clean
stack exec site build

# Get previous files
git fetch --all
git checkout master

# Overwrite existing files with new files
rsync -a --filter='P _site/' --filter='P .git/' --filter='P .gitignore' --filter='P .nojekyll' --delete-excluded _site/ .

# Commit
git add -A
git commit -m "Publish."

# Push
git push origin master:master

# Restoration
git checkout hakyll
git branch -D master
git stash pop
