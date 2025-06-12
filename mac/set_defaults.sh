# Hide Safari bookmark bar
defaults write com.apple.Safari ShowFavoritesBar -bool false

# Set Safari to dev mode
defaults write com.apple.Safari IncludeInternalDebugMenu -bool true
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari "com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled" -bool true
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

# Always open Finder in list view
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Use AirDrop over every interface
defaults write com.apple.NetworkBrowser BrowseAllInterfaces 1

# Fast keyboard repeat rate
defaults write NSGlobalDomain KeyRepeat -int 1
defaults write NSGlobalDomain InitialKeyRepeat -int 10

# Require password immediately after display sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -int 1
defaults write com.apple.screensaver askForPasswordDelay -int 0

# Set Dock icon size to 36 pixels
defaults write com.apple.dock tilesize -int 48

# Set Dock minimize effect to scale
defaults write com.apple.dock mineffect -string "scale"

# Auto-hide the Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -int 0
defaults write com.apple.dock autohide-time-modifier -float 0.4

# Speedup dock animations
defaults write com.apple.dock springboard-show-duration -float .1
defaults write com.apple.dock springboard-page-duration -float .2

# Increase file limits
sudo sysctl kern.maxfiles=64000 kern.maxfilesperproc=28000
