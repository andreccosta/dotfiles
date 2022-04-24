#!/usr/bin/env sh
defaults write com.apple.dock persistent-apps -array && killall Dock
