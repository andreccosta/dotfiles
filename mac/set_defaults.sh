#!/usr/bin/env bash

# Hide Safari bookmark bar
defaults write com.apple.Safari ShowFavoritesBar -bool false

# Set Safari to dev mode
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# In Safari, don't send search queries to Apple
defaults write com.apple.Safari UniversalSearchEnabled -bool false
defaults write com.apple.Safari SuppressSearchSuggestions -bool true

# Always open Finder in list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Show more things in a Finder window
defaults write NSGlobalDomain AppleShowAllFiles -bool true # show hidden files
defaults write NSGlobalDomain AppleShowAllExtensions -bool true # always show extensions
defaults write NSGlobalDomain ShowStatusBar -bool true # show status bar
defaults write NSGlobalDomain ShowPathbar -bool true # show path bar

# Use AirDrop over every interface
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

# Fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Enable full keyboard access for all controls (Accessibility pane)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 2

# Press-and-hold should repeat the key, not pop a dialog for special keys.
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# Touchpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true
sudo defaults write /Library/Preferences/.GlobalPreferences com.apple.mouse.tapBehavior -int 1

# Require password immediately after display sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Hide desktop icons
defaults write NSGlobalDomain CreateDesktop false

# Set Dock icon size to 36 pixels
defaults write com.apple.dock tilesize -int 50

# Set Dock minimize effect to scale
defaults write com.apple.dock mineffect -string "scale"

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -int 0
defaults write com.apple.dock autohide-time-modifier -float 0.4

# Speedup dock animations
defaults write com.apple.dock springboard-show-duration -float .1
defaults write com.apple.dock springboard-page-duration -float .2

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Increase file limits
sudo sysctl kern.maxfiles=122880 kern.maxfilesperproc=61440
